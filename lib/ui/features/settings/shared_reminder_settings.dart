import 'package:cupertino_ui/cupertino_ui.dart';

import '../../../domain/models/shared_profile.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/list_row.dart';
import 'shared_settings_widgets.dart';

class SharedReminderSettings extends StatelessWidget {
  const SharedReminderSettings({
    required this.profile,
    required this.email,
    required this.loading,
    required this.onLeadChanged,
    required this.onEmailChanged,
    required this.onOpenWeb,
    super.key,
  });

  final SharedProfile? profile;
  final String? email;
  final bool loading;
  final ValueChanged<int>? onLeadChanged;
  final ValueChanged<bool>? onEmailChanged;
  final VoidCallback onOpenWeb;

  @override
  Widget build(BuildContext context) {
    final settings = profile;
    final chooseLead = onLeadChanged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Pd.s3,
      children: [
        if (settings == null)
          Semantics(
            liveRegion: true,
            child: SharedSettingsDetail(
              loading
                  ? 'Loading reminder settings…'
                  : 'Couldn’t load your email reminder settings.',
            ),
          ),
        Semantics(
          label: 'Reminder timing',
          container: true,
          child: Row(
            spacing: Pd.s2,
            children: [
              for (final days in SharedProfile.leadDayChoices)
                Expanded(
                  child: _LeadChoice(
                    key: ValueKey('shared-settings-lead-$days'),
                    days: days,
                    selected: days == settings?.leadDays,
                    onPressed: settings == null || chooseLead == null
                        ? null
                        : () => chooseLead(days),
                  ),
                ),
            ],
          ),
        ),
        Column(
          children: [
            _ReminderChannel(
              title: 'Email',
              detail: email,
              control: settings == null
                  ? null
                  : PdSwitch(
                      key: const ValueKey('shared-settings-email-reminders'),
                      value: settings.emailReminders,
                      onChanged: onEmailChanged,
                    ),
            ),
            const _ReminderChannel(
              title: 'Notifications on this phone',
              detail: 'Coming soon',
              control: PdSwitch(value: false),
            ),
            const _ReminderChannel(
              title: 'WhatsApp',
              detail: 'Coming soon with Pro',
              control: PdSwitch(value: false),
            ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SharedSettingsLink(
            key: const ValueKey('shared-settings-web-reminders'),
            label: 'More reminder options on web',
            color: Pd.lime,
            onPressed: onOpenWeb,
          ),
        ),
      ],
    );
  }
}

class _LeadChoice extends StatelessWidget {
  const _LeadChoice({
    required this.days,
    required this.selected,
    this.onPressed,
    super.key,
  });

  final int days;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: selected,
    inMutuallyExclusiveGroup: true,
    enabled: onPressed != null,
    label: '$days days before',
    onTap: onPressed,
    excludeSemantics: true,
    child: CupertinoButton(
      minimumSize: const Size.square(Pd.tapMin),
      padding: EdgeInsets.zero,
      focusColor: Pd.lime,
      onPressed: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: Pd.s1, vertical: Pd.s3),
        decoration: BoxDecoration(
          color: selected ? Pd.limeTint.withValues(alpha: 0.08) : null,
          border: Border.all(
            color: selected ? Pd.lime : Pd.line,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(Pd.rSm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              days.toString().padLeft(2, '0'),
              style: PdType.choiceNumber.copyWith(
                color: selected ? Pd.lime : Pd.text,
              ),
            ),
            Text(
              'DAYS BEFORE',
              textAlign: TextAlign.center,
              style: PdType.tabLabel.copyWith(color: Pd.textMuted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReminderChannel extends StatelessWidget {
  const _ReminderChannel({
    required this.title,
    required this.detail,
    this.control,
  });

  final String title;
  final String? detail;
  final PdSwitch? control;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Container(
      constraints: const BoxConstraints(minHeight: Pd.tapMin + Pd.s2),
      padding: const EdgeInsets.symmetric(vertical: Pd.s1),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Pd.hairline)),
      ),
      child: Row(
        spacing: Pd.s3,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PdType.bodyStrong),
                if (detail case final value?) SharedSettingsDetail(value),
              ],
            ),
          ),
          if (control case final widget?)
            SizedBox(height: Pd.tapMin, child: widget),
        ],
      ),
    ),
  );
}
