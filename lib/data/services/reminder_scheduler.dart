import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/formats.dart';
import '../../domain/item_status.dart';
import '../../domain/models/claim.dart';
import '../../domain/models/item.dart';
import '../repositories/claim_repository.dart';
import '../repositories/item_repository.dart';
import '../repositories/settings_repository.dart';
import 'today.dart';

class PlannedReminder {
  const PlannedReminder({
    required this.key,
    required this.at,
    required this.title,
    required this.body,
    required this.location,
    this.timeSensitive = false,
  });

  final String key;
  final DateTime at;
  final String title;
  final String body;
  final String location;
  final bool timeSensitive;

  int get id =>
      key.codeUnits.fold(0, (hash, unit) => (hash * 31 + unit) & 0x7fffffff);
}

List<PlannedReminder> planReminders({
  required List<Item> items,
  required List<Claim> claims,
  required int leadDays,
  required DateTime now,
}) {
  final plans = <PlannedReminder>[];
  DateTime localMorning(DateTime day) =>
      DateTime(day.year, day.month, day.day, 9);
  for (final item in items) {
    if (item.isArchived || !item.draft.remind) continue;
    for (final window in windowsOf(item)) {
      if (window.isEnded(civil(now))) continue;
      final offsets = [
        leadDays,
        if (window.type == WindowType.returnWindow && leadDays > 1) 1,
      ];
      for (final days in offsets) {
        final morning = localMorning(addDays(window.end, -days));
        if (!morning.isAfter(now)) continue;
        plans.add(
          PlannedReminder(
            key: 'item/${item.id}/${window.type.name}/$days',
            at: morning,
            title: '${item.name} ${window.fact(civil(morning))}',
            body: window.action(),
            location: '/vault/item/${item.id}',
            timeSensitive: window.type == WindowType.returnWindow && days == 1,
          ),
        );
      }
    }
  }
  for (final claim in claims) {
    final followUp = claim.followUp;
    if (claim.isOpen && followUp != null && followUp.isAfter(now)) {
      plans.add(claimFollowUp(claim.id, claim.title, followUp));
    }
  }
  plans.sort((a, b) {
    final time = a.at.compareTo(b.at);
    return time == 0 ? a.key.compareTo(b.key) : time;
  });
  return plans.take(60).toList(growable: false);
}

PlannedReminder claimFollowUp(String id, String title, DateTime at) =>
    PlannedReminder(
      key: 'claim/$id',
      at: at.toLocal(),
      title: 'Follow up on $title',
      body: 'Open the claim ledger to see your entries.',
      location: '/claims/$id',
    );

abstract interface class NotificationGateway {
  Future<void> initialize(void Function(String) onTap);
  Future<bool> requestPermission();
  Future<void> cancelAll();
  Future<void> schedule(PlannedReminder reminder);
  Future<String?> launchLocation();
}

class FlutterLocalNotificationsGateway implements NotificationGateway {
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> initialize(void Function(String) onTap) async {
    if (!Platform.isIOS) return;
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final location = response.payload;
        if (location != null) onTap(location);
      },
    );
  }

  @override
  Future<bool> requestPermission() async {
    if (!Platform.isIOS) return false;
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> cancelAll() async {
    if (Platform.isIOS) await _plugin.cancelAllPendingNotifications();
  }

  Future<void> cancelClaimReminders() async {
    if (!Platform.isIOS) return;
    for (final pending in await _plugin.pendingNotificationRequests()) {
      if (pending.payload?.startsWith('/claims/') ?? false) {
        await _plugin.cancel(id: pending.id);
      }
    }
  }

  @override
  Future<void> schedule(PlannedReminder reminder) async {
    if (!Platform.isIOS) return;
    final at = reminder.at;
    await _plugin.zonedSchedule(
      id: reminder.id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: NotificationDetails(
        iOS: DarwinNotificationDetails(
          interruptionLevel: reminder.timeSensitive
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: reminder.title,
      body: reminder.body,
      payload: reminder.location,
    );
  }

  @override
  Future<String?> launchLocation() async {
    if (!Platform.isIOS) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details!.notificationResponse?.payload
        : null;
  }
}

class ReminderScheduler {
  ReminderScheduler({
    required this._gateway,
    required this._items,
    required this._claims,
    required this._settings,
    required this._today,
  });

  final NotificationGateway _gateway;
  final ItemRepository _items;
  final ClaimRepository _claims;
  final SettingsRepository _settings;
  final Today _today;
  final _taps = StreamController<String>.broadcast();
  late final Future<void> _initialization = _gateway.initialize(_taps.add);
  Timer? _debounce;
  Future<void> _scheduled = Future.value();
  bool _started = false;

  Stream<String> get taps => _taps.stream;

  void start() {
    if (_started) return;
    _started = true;
    _items.addListener(_queue);
    _claims.addListener(_queue);
    _settings.addListener(_queue);
    _today.addListener(_queue);
    _queue();
  }

  Future<bool> requestPermission() async {
    await _initialization;
    return _gateway.requestPermission();
  }

  Future<String?> launchLocation() async {
    await _initialization;
    return _gateway.launchLocation();
  }

  void _queue() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _scheduled = _scheduled.then((_) => _reschedule());
    });
  }

  Future<void> _reschedule() async {
    try {
      await _initialization;
      await _gateway.cancelAll();
      if (!_settings.remindersOn) return;
      final plans = planReminders(
        items: _items.active,
        claims: _claims.claims,
        leadDays: _settings.leadDays,
        now: _today.instant,
      );
      for (final reminder in plans) {
        await _gateway.schedule(reminder);
      }
    } catch (_) {
      // Platform scheduling is optional. The next change can try again.
    }
  }
}
