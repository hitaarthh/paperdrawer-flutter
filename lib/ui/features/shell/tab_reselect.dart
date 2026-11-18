import 'package:flutter/foundation.dart';

/// Fired when the user taps the tab they are already on. Tab root screens
/// listen and scroll their list back to the top.
class TabReselect extends ChangeNotifier {
  int _index = -1;

  /// The tab that was tapped again most recently.
  int get index => _index;

  void fire(int index) {
    _index = index;
    notifyListeners();
  }
}
