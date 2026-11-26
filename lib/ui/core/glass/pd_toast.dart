import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/pd_dynamic_type.dart';
import '../theme/pd_metrics.dart';
import '../theme/pd_theme.dart';
import 'pd_glass.dart';
import 'pd_pressable.dart';

/// One confirmation: a past-tense sentence with the useful fact ("Saved.
/// First reminder on 17 Nov.") and an optional Undo.
@immutable
final class PdToastMessage {
  const PdToastMessage(this.text, {this.onUndo, this.undoLabel = 'Undo'});

  final String text;
  final VoidCallback? onUndo;
  final String undoLabel;

  bool get hasUndo => onUndo != null;

  /// How long it stays: 4 s, 6 s with Undo.
  Duration get duration => hasUndo ? PdMotion.toastWithUndo : PdMotion.toast;
}

/// Shows one toast at a time (a new one replaces the old; they never stack)
/// and hides it after [PdToastMessage.duration]. The timer pauses while
/// VoiceOver focus is on the toast.
final class PdToastController extends ChangeNotifier {
  PdToastController({this.haptics = true});

  /// Plays the light success haptic when a toast appears.
  final bool haptics;

  PdToastMessage? _current;
  Timer? _timer;
  bool _held = false;
  bool _disposed = false;

  PdToastMessage? get current => _current;

  void show(PdToastMessage message) {
    if (_disposed) return;
    _current = message;
    _held = false;
    _restartTimer();
    if (haptics) unawaited(HapticFeedback.lightImpact());
    notifyListeners();
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (_current == null || _disposed) return;
    _current = null;
    notifyListeners();
  }

  /// VoiceOver focus moved onto ([held] true) or off the toast.
  void holdForAccessibility(bool held) {
    if (_held == held || _current == null) return;
    _held = held;
    if (held) {
      _timer?.cancel();
      _timer = null;
    } else {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    final message = _current;
    if (message == null || _held) return;
    _timer = Timer(message.duration, dismiss);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// The glass toast capsule: a `settled` check, the sentence in `subhead`,
/// and an optional small Undo in `limeText`. It sits where the
/// DeadlineAccessory sits and replaces it while visible.
final class PdToast extends StatelessWidget {
  const PdToast({
    required this.message,
    this.onUndo,
    this.onAccessibilityFocus,
    super.key = const ValueKey('toast'),
  });

  final PdToastMessage message;

  /// Called after Undo runs [PdToastMessage.onUndo] (to hide the toast).
  final VoidCallback? onUndo;
  final ValueChanged<bool>? onAccessibilityFocus;

  @override
  Widget build(BuildContext context) {
    final pd = context.pd;
    final undo = message.onUndo;
    return PdDynamicType.chrome(
      child: Semantics(
        container: true,
        liveRegion: true,
        onDidGainAccessibilityFocus: () => onAccessibilityFocus?.call(true),
        onDidLoseAccessibilityFocus: () => onAccessibilityFocus?.call(false),
        child: PdGlass(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: PdSize.accessoryHeight,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: PdSpace.s4,
                end: PdSpace.s1,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      LucideIcons.check,
                      size: PdSize.iconButton,
                      color: pd.colors.settled,
                    ),
                  ),
                  const SizedBox(width: PdSpace.s2),
                  Expanded(
                    child: Text(
                      message.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: pd.type.subhead.copyWith(color: pd.colors.text),
                    ),
                  ),
                  if (undo != null)
                    PdPressable(
                      key: const ValueKey('toast-undo'),
                      semanticLabel: message.undoLabel,
                      onPressed: () {
                        undo();
                        onUndo?.call();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PdSpace.s3,
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            message.undoLabel,
                            maxLines: 1,
                            style: pd.type.subhead.copyWith(
                              color: pd.colors.limeText,
                              fontWeight: pd.type.button.fontWeight,
                              fontVariations: pd.type.button.fontVariations,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
