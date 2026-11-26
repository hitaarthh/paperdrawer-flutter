import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/formats.dart';
import '../../domain/item_status.dart';
import '../../domain/models/item.dart';
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
  required int leadDays,
  required DateTime now,
}) {
  final plans = <PlannedReminder>[];
  DateTime localMorning(DateTime day) =>
      DateTime(day.year, day.month, day.day, 9);
  for (final item in items) {
    if (item.isArchived || !item.draft.remind) continue;
    if (item.draft.reminderAt case final at?) {
      if (at.isAfter(now)) {
        plans.add(
          PlannedReminder(
            key: 'item/${item.id}/custom',
            at: at.toLocal(),
            title: item.name,
            body: 'Open your drawer to see this file.',
            location: '/vault/item/${item.id}',
          ),
        );
      }
      continue;
    }
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
  plans.sort((a, b) {
    final time = a.at.compareTo(b.at);
    return time == 0 ? a.key.compareTo(b.key) : time;
  });
  return plans.take(60).toList(growable: false);
}

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

  Future<void> clear() async {
    if (Platform.isIOS) await _plugin.cancelAll();
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
    required this._settings,
    required this._today,
    this._accountScope,
  });

  final NotificationGateway _gateway;
  final ItemRepository _items;
  final SettingsRepository _settings;
  final Today _today;
  final String? _accountScope;
  final _taps = StreamController<String>.broadcast();
  late final Future<void> _initialization = _gateway.initialize((payload) {
    final location = _location(payload);
    if (_started && location != null) _taps.add(location);
  });
  Timer? _debounce;
  Future<void> _scheduled = Future.value();
  bool _started = false;

  Stream<String> get taps => _taps.stream;

  void start() {
    if (_started) return;
    _started = true;
    _items.addListener(_queue);
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
    return _location(await _gateway.launchLocation());
  }

  String? _location(String? payload) {
    final scope = _accountScope;
    if (scope == null) return payload?.startsWith('/') == true ? payload : null;
    final prefix = '$scope|';
    return payload?.startsWith(prefix) == true
        ? payload!.substring(prefix.length)
        : null;
  }

  Future<void> close() async {
    _started = false;
    _debounce?.cancel();
    _items.removeListener(_queue);
    _settings.removeListener(_queue);
    _today.removeListener(_queue);
    await _scheduled;
    if (_accountScope != null) {
      try {
        await _initialization;
        if (_gateway case final FlutterLocalNotificationsGateway platform) {
          await platform.clear();
        } else {
          await _gateway.cancelAll();
        }
      } catch (_) {
        // Scoped payloads still prevent old notifications opening the drawer.
      }
    }
    await _taps.close();
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
      if (!_started || !_settings.remindersOn) return;
      final plans = planReminders(
        items: _items.active,
        leadDays: _settings.leadDays,
        now: _today.instant,
      );
      for (final reminder in plans) {
        if (!_started) return;
        final scope = _accountScope;
        await _gateway.schedule(
          scope == null
              ? reminder
              : PlannedReminder(
                  key: '$scope|${reminder.key}',
                  at: reminder.at,
                  title: 'Paper Drawer reminder',
                  body: 'Open your drawer to see what’s due.',
                  location: '$scope|${reminder.location}',
                  timeSensitive: reminder.timeSensitive,
                ),
        );
      }
    } catch (_) {
      // Platform scheduling is optional. The next change can try again.
    }
  }
}
