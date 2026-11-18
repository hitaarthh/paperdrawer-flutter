import 'package:flutter/foundation.dart';

import '../../domain/formats.dart';

/// The user's local calendar date. Views rebuild when the day changes, e.g.
/// when the app comes back to the foreground after midnight.
class Today extends ChangeNotifier {
  Today([DateTime Function()? now]) : _now = now ?? DateTime.now {
    _value = civil(_now());
  }

  final DateTime Function() _now;
  late DateTime _value;

  DateTime get value => _value;

  void refresh() {
    final next = civil(_now());
    if (next != _value) {
      _value = next;
      notifyListeners();
    }
  }
}
