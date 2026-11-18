import 'package:cupertino_ui/cupertino_ui.dart';

import '../../../domain/item_status.dart';
import '../../../domain/models/shared_vault.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/meter.dart';

class SharedSettingsSection extends StatelessWidget {
  const SharedSettingsSection({
    required this.number,
    required this.title,
    required this.description,
    required this.children,
    super.key,
  });

  final String number;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(top: Pd.s5),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Pd.hairline)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Pd.s3,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: Pd.s3,
          children: [
            ExcludeSemantics(
              child: Text(
                number,
                style: PdType.monoButton.copyWith(color: Pd.lime),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Pd.s1,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: PdType.title2),
                  ),
                  SharedSettingsDetail(description),
                ],
              ),
            ),
          ],
        ),
        ...children,
      ],
    ),
  );
}

class SharedSettingsDetail extends StatelessWidget {
  const SharedSettingsDetail(this.text, {this.mono = false, super.key});

  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: (mono ? PdType.meta : PdType.detail).copyWith(color: Pd.textMuted),
  );
}

class SharedSettingsLink extends StatelessWidget {
  const SharedSettingsLink({
    required this.label,
    required this.onPressed,
    this.color = Pd.textMuted,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size.square(Pd.tapMin),
    focusColor: Pd.lime,
    onPressed: onPressed,
    child: Text(
      label.toUpperCase(),
      semanticsLabel: label,
      style: PdType.meta.copyWith(color: color),
    ),
  );
}

class SharedSettingsAccount extends StatelessWidget {
  const SharedSettingsAccount({
    required this.name,
    required this.email,
    required this.signingOut,
    required this.onSignOut,
    super.key,
  });

  final String name;
  final String? email;
  final bool signingOut;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Pd.s3,
      children: [
        Row(
          spacing: Pd.s3,
          children: [
            ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: Pd.tapMin,
                  minWidth: Pd.tapMin,
                ),
                padding: const EdgeInsets.all(Pd.s1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Pd.line),
                  borderRadius: BorderRadius.circular(Pd.rSm),
                ),
                child: Text(initials, style: PdType.monoButton),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: PdType.bodyStrong),
                  if (email case final value?) SharedSettingsDetail(value),
                ],
              ),
            ),
          ],
        ),
        Row(
          spacing: Pd.s2,
          children: [
            Expanded(
              child: SharedSettingsDetail(
                email == null ? '' : 'SIGNED IN WITH EMAIL',
                mono: true,
              ),
            ),
            PdButton.secondary(
              key: const ValueKey('account-sign-out'),
              label: 'Sign out',
              busy: signingOut,
              onPressed: onSignOut,
            ),
          ],
        ),
      ],
    );
  }
}

class SharedSettingsPlan extends StatelessWidget {
  const SharedSettingsPlan({
    required this.vault,
    required this.failed,
    required this.onRetry,
    required this.onSeePlans,
    super.key,
  });

  final SharedVault? vault;
  final bool failed;
  final VoidCallback onRetry;
  final VoidCallback onSeePlans;

  @override
  Widget build(BuildContext context) {
    final snapshot = vault;
    final used = snapshot?.items.length;
    final onBase = snapshot?.onBasePlan ?? false;
    return Container(
      padding: const EdgeInsets.all(Pd.s4),
      decoration: BoxDecoration(
        color: Pd.surface2,
        borderRadius: BorderRadius.circular(Pd.rSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Pd.s2,
        children: [
          if (used != null) ...[
            Row(
              spacing: Pd.s2,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    onBase ? 'BASE · FREE' : 'PRO',
                    style: PdType.monoButton.copyWith(color: Pd.lime),
                  ),
                ),
                Flexible(
                  child: Text(
                    onBase
                        ? '$used OF $baseItemLimit ITEMS'
                        : '$used ${used == 1 ? 'ITEM' : 'ITEMS'}',
                    textAlign: TextAlign.end,
                    style: PdType.data,
                  ),
                ),
              ],
            ),
            if (onBase) ...[
              MeterBar(fraction: used / baseItemLimit),
              const SharedSettingsDetail(
                'Reminders, claims and export stay available when your vault is full.',
              ),
            ] else
              const SharedSettingsDetail('Your plan includes unlimited items.'),
          ] else
            Semantics(
              liveRegion: true,
              child: SharedSettingsDetail(
                failed ? 'Couldn’t load plan usage.' : 'Loading plan usage…',
              ),
            ),
          Row(
            spacing: Pd.s2,
            children: [
              Expanded(
                child: used == null && failed
                    ? Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SharedSettingsLink(
                          label: 'Retry',
                          onPressed: onRetry,
                        ),
                      )
                    : onBase
                    ? const SharedSettingsDetail(
                        'PRO WAITLIST COMING SOON',
                        mono: true,
                      )
                    : const SizedBox.shrink(),
              ),
              SharedSettingsLink(
                key: const ValueKey('shared-settings-plans'),
                label: 'See plans',
                color: Pd.lime,
                onPressed: onSeePlans,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SharedSettingsDataAction extends StatelessWidget {
  const SharedSettingsDataAction({
    required this.title,
    required this.description,
    required this.button,
    this.separated = false,
    super.key,
  });

  final String title;
  final String description;
  final Widget button;
  final bool separated;

  @override
  Widget build(BuildContext context) => Container(
    decoration: separated
        ? const BoxDecoration(
            border: Border(top: BorderSide(color: Pd.hairline)),
          )
        : null,
    padding: separated ? const EdgeInsets.only(top: Pd.s4) : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Pd.s1,
      children: [
        Text(title, style: PdType.bodyStrong),
        SharedSettingsDetail(description),
        Padding(
          padding: const EdgeInsets.only(top: Pd.s2),
          child: button,
        ),
      ],
    ),
  );
}

class SharedSettingsFooter extends StatelessWidget {
  const SharedSettingsFooter({
    required this.version,
    required this.onPrivacy,
    required this.onTerms,
    super.key,
  });

  final Future<String?> version;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;

  @override
  Widget build(BuildContext context) => Row(
    spacing: Pd.s2,
    children: [
      Expanded(
        child: Wrap(
          spacing: Pd.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SharedSettingsLink(
              key: const ValueKey('shared-settings-privacy'),
              label: 'Privacy',
              onPressed: onPrivacy,
            ),
            const ExcludeSemantics(
              child: SharedSettingsDetail('·', mono: true),
            ),
            SharedSettingsLink(
              key: const ValueKey('shared-settings-terms'),
              label: 'Terms',
              onPressed: onTerms,
            ),
          ],
        ),
      ),
      Flexible(
        child: FutureBuilder(
          future: version,
          builder: (context, snapshot) {
            if (snapshot.data case final String version) {
              return SharedSettingsDetail('VERSION $version', mono: true);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    ],
  );
}
