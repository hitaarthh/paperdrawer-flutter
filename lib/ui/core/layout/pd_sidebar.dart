import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../glass/pd_destination.dart';
import '../glass/pd_glass.dart';
import '../glass/pd_pressable.dart';
import '../theme/pd_metrics.dart';
import '../theme/pd_theme.dart';
import '../widgets/icons.dart';

/// One Vault filter in the sidebar: `DUE SOON 4`.
@immutable
final class PdSidebarFilter {
  const PdSidebarFilter({
    required this.id,
    required this.label,
    required this.count,
    this.due = false,
  });

  /// Kebab-case id; the key is `sidebar-filter-<id>`.
  final String id;

  /// Caps label: `DUE SOON`.
  final String label;
  final int count;

  /// The count is time-close (`signal`).
  final bool due;

  @override
  bool operator ==(Object other) =>
      other is PdSidebarFilter &&
      other.id == id &&
      other.label == label &&
      other.count == count &&
      other.due == due;

  @override
  int get hashCode => Object.hash(id, label, count, due);
}

/// The filter section under the destinations (the Vault filters).
@immutable
final class PdSidebarFilters {
  const PdSidebarFilters({
    required this.title,
    required this.filters,
    required this.onSelected,
    this.selectedId,
  });

  /// Caps header: `VAULT`.
  final String title;
  final List<PdSidebarFilter> filters;
  final ValueChanged<PdSidebarFilter> onSelected;
  final String? selectedId;
}

/// The regular-width glass sidebar: optional brand on top, the
/// destinations with counts, an optional filter section, and the lime
/// "Scan or add" capsule at the bottom (the one lime thing on screen).
/// The list scrolls at large text sizes; the button stays at the bottom.
final class PdSidebar extends StatelessWidget {
  const PdSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onScan,
    this.filters,
    this.brand,
    this.scanLabel = 'Scan or add',
    super.key = const ValueKey('sidebar'),
  });

  final List<PdDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onScan;
  final PdSidebarFilters? filters;
  final Widget? brand;
  final String scanLabel;

  @override
  Widget build(BuildContext context) {
    final brand = this.brand;
    final filters = this.filters;
    return PdGlass(
      shape: PdGlassShape.rounded,
      cornerRadius: PdRadius.lg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PdSpace.s2 + PdSpace.s1 / 2,
          PdSpace.s5,
          PdSpace.s2 + PdSpace.s1 / 2,
          PdSpace.s3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                primary: false,
                padding: EdgeInsets.zero,
                children: [
                  if (brand != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        PdSpace.s3,
                        0,
                        PdSpace.s3,
                        PdSpace.s4,
                      ),
                      child: brand,
                    ),
                  for (final (index, destination) in destinations.indexed)
                    _DestinationRow(
                      destination: destination,
                      selected: index == selectedIndex,
                      onPressed: () => onDestinationSelected(index),
                    ),
                  if (filters != null) ..._filterSection(context, filters),
                ],
              ),
            ),
            const SizedBox(height: PdSpace.s2),
            _ScanOrAdd(label: scanLabel, onPressed: onScan),
          ],
        ),
      ),
    );
  }

  List<Widget> _filterSection(BuildContext context, PdSidebarFilters filters) {
    final pd = context.pd;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          PdSpace.s3 + PdSpace.s1 / 2,
          PdSpace.s5,
          PdSpace.s3 + PdSpace.s1 / 2,
          PdSpace.s1 + PdSpace.s1 / 2,
        ),
        child: Semantics(
          header: true,
          child: Text(
            filters.title,
            style: pd.type.label.copyWith(color: pd.colors.textMuted),
          ),
        ),
      ),
      for (final filter in filters.filters)
        _FilterRow(
          filter: filter,
          selected: filter.id == filters.selectedId,
          onPressed: () => filters.onSelected(filter),
        ),
    ];
  }
}

final class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final PdDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final pd = context.pd;
    // Canvas: the selected destination is lime (olive in light).
    final color = selected ? pd.colors.limeText : pd.colors.text;
    final count = destination.count;
    return PdPressable(
      key: ValueKey('sidebar-${destination.id}'),
      semanticLabel: count == null
          ? destination.label
          : '${destination.label}, $count',
      selected: selected,
      inMutuallyExclusiveGroup: true,
      pressedScale: 1,
      onPressed: onPressed,
      child: _RowCapsule(
        selected: selected,
        child: Row(
          children: [
            PdIcon(destination.glyph, size: PdSize.iconBar, color: color),
            const SizedBox(width: PdSpace.s3),
            Expanded(
              child: Text(
                destination.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (selected ? pd.type.bodyStrong : pd.type.body).copyWith(
                  color: color,
                ),
              ),
            ),
            if (count != null)
              Text(
                '$count',
                style: pd.type.label.copyWith(color: pd.colors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

final class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filter,
    required this.selected,
    required this.onPressed,
  });

  final PdSidebarFilter filter;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final pd = context.pd;
    return PdPressable(
      key: ValueKey('sidebar-filter-${filter.id}'),
      semanticLabel: '${filter.label}, ${filter.count}',
      selected: selected,
      inMutuallyExclusiveGroup: true,
      pressedScale: 1,
      onPressed: onPressed,
      child: _RowCapsule(
        selected: selected,
        child: Row(
          children: [
            Expanded(
              child: Text(
                filter.label,
                style: pd.type.label.copyWith(
                  color: selected ? pd.colors.text : pd.colors.text2,
                ),
              ),
            ),
            const SizedBox(width: PdSpace.s2),
            Text(
              '${filter.count}',
              style: pd.type.label.copyWith(
                color: filter.due ? pd.colors.signal : pd.colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 44 pt row with the `glass-selection` capsule when selected.
final class _RowCapsule extends StatelessWidget {
  const _RowCapsule({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: selected ? context.pd.colors.glassSelection : null,
      borderRadius: BorderRadius.circular(PdRadius.pill),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PdSize.tapMin),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PdSpace.s3 + PdSpace.s1 / 2,
          vertical: PdSpace.s1,
        ),
        child: Center(child: child),
      ),
    ),
  );
}

final class _ScanOrAdd extends StatelessWidget {
  const _ScanOrAdd({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final pd = context.pd;
    return PdPressable(
      key: const ValueKey('scan-or-add'),
      semanticLabel: label,
      onPressed: onPressed,
      child: PdGlass(
        tint: PdGlassTint.lime,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: PdSize.controlHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PdSpace.s4,
              vertical: PdSpace.s2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PdIcon(
                  PdGlyph.scan,
                  size: PdSize.iconButton,
                  color: pd.colors.onLime,
                ),
                const SizedBox(width: PdSpace.s2 + PdSpace.s1 / 2),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: pd.type.button.copyWith(color: pd.colors.onLime),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
