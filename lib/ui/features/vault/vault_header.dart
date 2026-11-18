import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/item_status.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';

/// The mono kicker ("010 ITEMS · 4 DUE SOON") over the "The vault" headline.
class VaultHeader extends StatelessWidget {
  const VaultHeader({required this.kicker, super.key});

  final String kicker;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: Pd.s2,
    children: [
      Text(
        kicker,
        key: const ValueKey('vault-kicker'),
        style: PdType.label.copyWith(color: Pd.textMuted),
      ),
      Semantics(
        header: true,
        child: Text('The vault', style: PdType.heroTitle),
      ),
    ],
  );
}

/// "Search your vault", with how much of the Base plan is used on the right.
class VaultSearchField extends StatefulWidget {
  const VaultSearchField({
    required this.controller,
    required this.onChanged,
    required this.count,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Active items, shown as "10 OF 25".
  final int count;

  @override
  State<VaultSearchField> createState() => _VaultSearchFieldState();
}

class _VaultSearchFieldState extends State<VaultSearchField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _focus
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: Pd.tapMin),
    child: CupertinoTextField(
      key: const ValueKey('vault-search'),
      controller: widget.controller,
      focusNode: _focus,
      onChanged: widget.onChanged,
      placeholder: 'Search your vault',
      placeholderStyle: PdType.body.copyWith(color: Pd.placeholder),
      style: PdType.body,
      cursorColor: Pd.lime,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      padding: const EdgeInsets.symmetric(
        horizontal: Pd.s3,
        vertical: Pd.s3,
      ),
      prefix: const Padding(
        padding: EdgeInsets.only(left: Pd.s3),
        child: Icon(LucideIcons.search, size: Pd.iconSm, color: Pd.placeholder),
      ),
      suffix: Padding(
        padding: const EdgeInsets.only(right: Pd.s3),
        child: Text(
          '${widget.count} OF $baseItemLimit',
          semanticsLabel: '${widget.count} of $baseItemLimit items on Base',
          style: PdType.label.copyWith(
            color: Pd.textMuted,
            fontWeight: FontWeight.w400,
            fontVariations: const [FontVariation.weight(400)],
          ),
        ),
      ),
      suffixMode: OverlayVisibilityMode.notEditing,
      clearButtonMode: OverlayVisibilityMode.editing,
      clearButtonSemanticLabel: 'Clear search',
      decoration: BoxDecoration(
        color: Pd.surface1,
        border: Border.all(color: _focus.hasFocus ? Pd.lime : Pd.line),
        borderRadius: BorderRadius.circular(Pd.rSm),
      ),
    ),
  );
}

/// Underlined filter tabs: ALL 10 · DUE SOON 4 · IN CLAIM 1 · COVERED · ENDED.
class VaultFilterTabs extends StatelessWidget {
  const VaultFilterTabs({
    required this.selected,
    required this.count,
    required this.onSelect,
    super.key,
  });

  final VaultFilter selected;
  final int Function(VaultFilter) count;
  final ValueChanged<VaultFilter> onSelect;

  static String label(VaultFilter filter) => switch (filter) {
    VaultFilter.all => 'ALL',
    VaultFilter.due => 'DUE SOON',
    VaultFilter.inClaim => 'IN CLAIM',
    VaultFilter.covered => 'COVERED',
    VaultFilter.expired => 'ENDED',
  };

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Pd.hairline)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Pd.margin),
      child: Row(
        spacing: Pd.s5,
        children: [
          for (final filter in VaultFilter.values)
            _Tab(
              key: ValueKey('vault-filter-${filter.name}'),
              label: label(filter),
              count: count(filter),
              selected: filter == selected,
              onTap: () => onSelect(filter),
            ),
        ],
      ),
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = PdType.monoButton.copyWith(
      color: selected ? Pd.text : Pd.textSubtle,
      fontWeight: FontWeight.w400,
      fontVariations: const [FontVariation.weight(400)],
    );
    return Semantics(
      selected: selected,
      button: true,
      label: '$label, $count',
      excludeSemantics: true,
      child: CupertinoButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        pressedOpacity: 0.7,
        focusColor: Pd.lime,
        minimumSize: const Size.square(Pd.tapMin),
        child: Container(
          constraints: const BoxConstraints(minHeight: Pd.tapMin),
          padding: const EdgeInsets.symmetric(vertical: Pd.s2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Pd.lime : const Color(0x00000000),
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text.rich(
            TextSpan(
              text: label,
              children: [
                TextSpan(
                  text: ' $count',
                  style: TextStyle(
                    color: selected ? Pd.lime : Pd.textSubtle,
                  ),
                ),
              ],
            ),
            style: style,
          ),
        ),
      ),
    );
  }
}
