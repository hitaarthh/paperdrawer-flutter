import 'dart:async';

import '../../domain/models/shared_vault.dart';
import 'reminder_scheduler.dart';

/// The shared build schedules only the follow-ups people set on their claims.
class SharedClaimReminders {
  final _gateway = FlutterLocalNotificationsGateway();
  final _taps = StreamController<String>.broadcast();
  late final _initialized = _gateway.initialize((location) {
    if (!_taps.isClosed) _taps.add(location);
  });
  Future<void> _pending = Future.value();

  Stream<String> get taps => _taps.stream;

  Future<String?> launchLocation() async {
    try {
      await _initialized;
      return await _gateway.launchLocation();
    } catch (_) {
      return null;
    }
  }

  Future<bool> requestPermission() async {
    try {
      await _initialized;
      return await _gateway.requestPermission();
    } catch (_) {
      return false;
    }
  }

  void sync(List<SharedClaim> claims, DateTime now) {
    _pending = _pending.then((_) async {
      try {
        await _initialized;
        await _gateway.cancelClaimReminders();
        final plans = [
          for (final claim in claims)
            if (claim.settled == null)
              if (claim.followUp case final time? when time.isAfter(now))
                claimFollowUp(claim.id, claim.title, time),
        ]..sort((a, b) => a.at.compareTo(b.at));
        for (final plan in plans.take(60)) {
          await _gateway.schedule(plan);
        }
      } catch (_) {
        // The stored follow-up still appears in the claim ledger.
      }
    });
  }

  void dispose() => unawaited(_taps.close());
}
