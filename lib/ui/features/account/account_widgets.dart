import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';

/// The SIGN IN / CREATE ACCOUNT strip above the account form: mono labels on
/// a hairline rule, with a 2pt lime underline under the selected tab.
class AccountTabs extends StatelessWidget {
  const AccountTabs({
    required this.creating,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final bool creating;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Pd.hairline)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: Pd.s6,
      children: [
        Flexible(
          child: _Tab(
            key: const ValueKey('account-tab-sign-in'),
            label: 'SIGN IN',
            selected: !creating,
            onTap: enabled ? () => onChanged(false) : null,
          ),
        ),
        Flexible(
          child: _Tab(
            key: const ValueKey('account-tab-create'),
            label: 'CREATE ACCOUNT',
            selected: creating,
            onTap: enabled ? () => onChanged(true) : null,
          ),
        ),
      ],
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    inMutuallyExclusiveGroup: true,
    enabled: onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: selected ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Pd.tapMin),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? Pd.lime : const Color(0x00000000),
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          // The design sets these at regular weight; selection reads from
          // the colour and the underline.
          style: PdType.monoButton.copyWith(
            fontWeight: FontWeight.w400,
            fontVariations: const [FontVariation.weight(400)],
            color: selected ? Pd.text : Pd.textSubtle,
          ),
        ),
      ),
    ),
  );
}

/// The account screen's display headline (heroTitle stepped to 40) and the
/// muted line under it.
class AccountHeading extends StatelessWidget {
  const AccountHeading({required this.title, required this.body, super.key});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: Pd.s2,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: PdType.heroTitle.copyWith(
            fontSize: 40,
            letterSpacing: 40 * -0.05,
          ),
        ),
      ),
      DefaultTextStyle.merge(
        style: PdType.callout.copyWith(color: Pd.textMuted),
        child: body,
      ),
    ],
  );
}

/// What PaperDrawer does with a new account, as three checked mono lines.
class AccountPromises extends StatelessWidget {
  const AccountPromises({super.key});

  static const _lines = [
    'WE ONLY ASK FOR YOUR NAME AND EMAIL',
    'BILLS ARE NEVER SOLD OR SHARED',
    'EXPORT OR DELETE ANY TIME',
  ];

  @override
  Widget build(BuildContext context) {
    final style = PdType.label.copyWith(
      fontWeight: FontWeight.w400,
      fontVariations: const [FontVariation.weight(400)],
      letterSpacing: 11 * 0.08,
      color: Pd.textMuted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Pd.s2,
      children: [
        for (final line in _lines)
          Row(
            spacing: Pd.s3,
            children: [
              // The design's 14pt check, a step under iconSm.
              const Icon(LucideIcons.check, size: 14, color: Pd.lime),
              Expanded(child: Text(line, style: style)),
            ],
          ),
      ],
    );
  }
}

/// "By continuing you agree to the Terms and Privacy policy." The two links
/// open the web pages and keep a full-height tap target.
class AccountLegalLine extends StatelessWidget {
  const AccountLegalLine({
    required this.onTerms,
    required this.onPrivacy,
    super.key,
  });

  final VoidCallback? onTerms;
  final VoidCallback? onPrivacy;

  @override
  Widget build(BuildContext context) {
    final style = PdType.footnote.copyWith(color: Pd.textMuted);
    return DefaultTextStyle.merge(
      style: style,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('By continuing you agree to the '),
          _InlineLink(
            key: const ValueKey('account-terms'),
            label: 'Terms',
            onTap: onTerms,
          ),
          const Text(' and '),
          _InlineLink(
            key: const ValueKey('account-privacy'),
            label: 'Privacy policy',
            onTap: onPrivacy,
          ),
          const Text('.'),
        ],
      ),
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    enabled: onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Pd.tapMin),
        child: Align(
          widthFactor: 1,
          child: Text(label, style: const TextStyle(color: Pd.lime)),
        ),
      ),
    ),
  );
}
