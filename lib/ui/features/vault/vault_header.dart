import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/item_status.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/filter_tabs.dart';

class VaultHeader extends StatelessWidget {
  const VaultHeader({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text('Your drawer', style: PdType.heroTitle),
  );
}

/// Drawer search with an optional file count.
class VaultSearchField extends StatefulWidget {
  const VaultSearchField({
    required this.controller,
    required this.onChanged,
    this.count,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Number of active files.
  final int? count;

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
      placeholder: 'Search your drawer',
      placeholderStyle: PdType.body.copyWith(color: Pd.placeholder),
      style: PdType.body,
      cursorColor: Pd.lime,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      padding: const EdgeInsets.symmetric(horizontal: Pd.s3, vertical: Pd.s3),
      prefix: const Padding(
        padding: EdgeInsets.only(left: Pd.s3),
        child: Icon(LucideIcons.search, size: Pd.iconSm, color: Pd.placeholder),
      ),
      suffix: widget.count == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: Pd.s3),
              child: Text(
                '${widget.count} ${widget.count == 1 ? 'FILE' : 'FILES'}',
                semanticsLabel: '${widget.count} files',
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

/// Underlined filters for the dates tracked in the drawer.
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
    VaultFilter.expired => 'EXPIRED',
    VaultFilter.undated => 'NO DATE',
  };

  @override
  Widget build(BuildContext context) => PdFilterTabs(
    children: [
      for (final filter in const [
        VaultFilter.all,
        VaultFilter.due,
        VaultFilter.covered,
        VaultFilter.expired,
        VaultFilter.undated,
      ])
        PdFilterTab(
          key: ValueKey('vault-filter-${filter.name}'),
          label: label(filter),
          count: count(filter),
          selected: filter == selected,
          onTap: () => onSelect(filter),
        ),
    ],
  );
}
