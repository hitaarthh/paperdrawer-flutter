import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoButton;
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/reminder_scheduler.dart';
import '../../../data/services/today.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/button.dart';
import 'notification_preview.dart';
import 'reminders_view_model.dart';

/// "Turn on reminders": the pre-permission offer shown once, right after the
/// first item with a cover window is saved. Its primary action raises the
/// iOS prompt through the same path as the Settings switch.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late final _model = RemindersViewModel(
    context.read<SettingsRepository>(),
    context.read<ReminderScheduler?>(),
  );

  /// Set once the user has answered, so leaving doesn't count as "Not now".
  bool _answered = false;

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.vault);
    }
  }

  Future<void> _turnOn() async {
    final on = await _model.turnOn();
    if (!mounted) return;
    if (on) {
      _answered = true;
      _close();
    } else if (_model.denied) {
      _answered = true;
    }
  }

  Future<void> _notNow() async {
    _answered = true;
    await _model.notNow();
    if (!mounted) return;
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final today = context.watch<Today>().value;
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) => PopScope(
        canPop: !_model.busy,
        onPopInvokedWithResult: (didPop, _) {
          // Swiping or going back is an answer too: don't ask again.
          if (didPop && !_answered) unawaited(_model.notNow());
        },
        child: Scaffold(
          backgroundColor: Pd.bg,
          body: CustomPaint(
            painter: const PaperGrain(),
            child: RepaintBoundary(
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: 'Turn on reminders',
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: Pd.maxContent),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const PdBrandBar(),
                        Expanded(child: _content(today)),
                        _actions(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(DateTime today) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Pd.margin,
            Pd.s8,
            Pd.margin,
            Pd.s10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NotificationPreview(today: today),
              const Spacer(),
              const SizedBox(height: Pd.s10),
              Text(
                'ONE LAST THING',
                style: PdType.label.copyWith(color: Pd.lime),
              ),
              const SizedBox(height: Pd.s3),
              Semantics(
                header: true,
                child: Text('A nudge on your phone?', style: PdType.heroTitle),
              ),
              const SizedBox(height: Pd.s3),
              Text(
                'Turn on notifications and we’ll tap you on the shoulder '
                '${_model.leadPhrase} before a return window closes, a '
                'warranty ends or a policy renews.',
                style: PdType.body.copyWith(color: Pd.textMuted),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _actions() {
    final model = _model;
    final message = model.denied
        ? 'No problem, notifications stay off. To turn them on later, allow '
              'Paper Drawer in your iPhone’s Settings, then switch on Device '
              'notifications in Settings here.'
        : model.error;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: Pd.s2),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Pd.margin, 0, Pd.margin, Pd.s2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Pd.s4),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    key: const ValueKey('reminders-message'),
                    style: PdType.callout.copyWith(color: Pd.text2),
                  ),
                ),
              ),
            if (model.denied)
              PdButton.primary(
                key: const ValueKey('reminders-done'),
                label: 'Done',
                expand: true,
                onPressed: _close,
              )
            else ...[
              PdButton.primary(
                key: const ValueKey('reminders-turn-on'),
                label: 'Turn on notifications',
                icon: const Icon(LucideIcons.bell),
                expand: true,
                busy: model.busy,
                onPressed: model.busy ? null : _turnOn,
              ),
              const SizedBox(height: Pd.s1),
              Center(
                child: _QuietLink(
                  key: const ValueKey('reminders-not-now'),
                  label: 'Not now',
                  onPressed: model.busy ? null : _notNow,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Muted text link from the mockups (15pt, `text-muted`, 44pt tall).
class _QuietLink extends StatelessWidget {
  const _QuietLink({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    onPressed: onPressed,
    padding: const EdgeInsets.symmetric(horizontal: Pd.s2),
    minimumSize: const Size(Pd.tapMin, Pd.tapMin),
    pressedOpacity: 0.7,
    focusColor: Pd.lime,
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: PdType.callout.copyWith(color: Pd.textMuted),
    ),
  );
}
