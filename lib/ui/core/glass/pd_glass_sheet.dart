import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart'
    show AnimationStyle, Colors, showModalBottomSheet;

import '../theme/pd_dynamic_type.dart';
import '../theme/pd_metrics.dart';
import '../theme/pd_theme.dart';
import 'glass_toolbar_button.dart';
import 'pd_glass.dart';

/// Sheet heights. Medium is inset glass; large is opaque and full width with
/// `scrim` behind.
enum PdSheetDetent { medium, large }

/// A sheet for a short task (Add, pick a date, a filter): grabber, a
/// `title-2` title with a round 36 pt glass close button (no "Cancel" text),
/// the content, at most one primary action and a row of secondary actions.
///
/// Present it with [showPdGlassSheet]. The primary action is a slot so the
/// screen's own lime button goes there; keep it to one.
final class PdGlassSheet extends StatelessWidget {
  const PdGlassSheet({
    required this.title,
    required this.child,
    required this.onClose,
    this.primaryAction,
    this.secondaryActions = const [],
    this.closeLabel = 'Close',
    this.detent = PdSheetDetent.medium,
    super.key,
  });

  final String title;
  final Widget child;
  final VoidCallback onClose;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;
  final String closeLabel;
  final PdSheetDetent detent;

  @override
  Widget build(BuildContext context) {
    final pd = context.pd;
    final media = MediaQuery.of(context);
    // At accessibility sizes the header and actions can't all stay pinned,
    // so the whole sheet scrolls.
    final scrollAll = PdDynamicType.isAccessibilitySize(context);
    final Widget body = scrollAll ? child : SingleChildScrollView(child: child);
    Widget content = Padding(
      padding: EdgeInsets.fromLTRB(
        PdSpace.s5,
        PdSpace.s2,
        PdSpace.s5,
        PdSpace.s5 + (detent == PdSheetDetent.large ? media.padding.bottom : 0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: PdSize.grabber.width,
              height: PdSize.grabber.height,
              decoration: BoxDecoration(
                color: pd.colors.textSubtle,
                borderRadius: BorderRadius.circular(PdRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: PdSpace.s3),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: pd.type.title2.copyWith(color: pd.colors.text),
                  ),
                ),
              ),
              const SizedBox(width: PdSpace.s2),
              GlassToolbarButton.icon(
                key: const ValueKey('sheet-close'),
                icon: const Icon(LucideIcons.x),
                systemIcon: 'xmark',
                semanticLabel: closeLabel,
                onPressed: onClose,
                visualSize: PdSize.sheetClose,
                iconSize: PdSize.iconButton,
              ),
            ],
          ),
          const SizedBox(height: PdSpace.s4),
          if (scrollAll) body else Flexible(child: body),
          if (primaryAction case final primary?) ...[
            const SizedBox(height: PdSpace.s4),
            primary,
          ],
          if (secondaryActions.isNotEmpty) ...[
            const SizedBox(height: PdSpace.s2),
            Row(
              children: [
                for (final (index, action) in secondaryActions.indexed) ...[
                  if (index > 0) const SizedBox(width: PdSpace.s2),
                  Expanded(child: action),
                ],
              ],
            ),
          ],
        ],
      ),
    );
    if (scrollAll) content = SingleChildScrollView(child: content);
    return switch (detent) {
      PdSheetDetent.medium => Padding(
        padding: EdgeInsets.fromLTRB(
          PdEffects.sheetInset,
          0,
          PdEffects.sheetInset,
          PdEffects.sheetInset + media.padding.bottom,
        ),
        child: PdGlass(
          shape: PdGlassShape.rounded,
          cornerRadius: PdRadius.xl,
          child: content,
        ),
      ),
      PdSheetDetent.large => DecoratedBox(
        decoration: BoxDecoration(
          color: pd.colors.surface2,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(PdRadius.xl),
          ),
          boxShadow: PdShadows.sheet(pd.colors),
          border: MediaQuery.highContrastOf(context)
              ? Border(top: BorderSide(color: pd.colors.line))
              : null,
        ),
        child: content,
      ),
    };
  }
}

/// Presents a sheet built by [builder] (usually a [PdGlassSheet]) and returns
/// what it pops. Never stack a sheet on a sheet.
///
/// iOS 26's native sheet can't host Flutter content through
/// `native_liquid_glass`, so this is a Flutter sheet with kit glass. With
/// Reduce Motion it appears without the slide.
Future<T?> showPdGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  PdSheetDetent detent = PdSheetDetent.medium,
  String? semanticLabel,
}) {
  final colors = context.pd.colors;
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    elevation: 0,
    backgroundColor: Colors.transparent,
    barrierColor: switch (detent) {
      PdSheetDetent.medium => colors.scrimMedium,
      PdSheetDetent.large => colors.scrim,
    },
    barrierLabel: semanticLabel,
    constraints: const BoxConstraints(maxWidth: PdSize.contentMax),
    sheetAnimationStyle: reduceMotion ? AnimationStyle.noAnimation : null,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: Semantics(
        scopesRoute: true,
        namesRoute: semanticLabel != null,
        label: semanticLabel,
        explicitChildNodes: true,
        child: Builder(builder: builder),
      ),
    ),
  );
}
