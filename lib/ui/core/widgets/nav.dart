import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart' show Scaffold;

import '../theme/tokens.dart';
import '../theme/type.dart';
import 'glass.dart';
import 'icons.dart';

class PdLargeTitleScaffold extends StatefulWidget {
  const PdLargeTitleScaffold({
    required this.title,
    this.trailing,
    required this.slivers,
    this.controller,
    this.heroTag = 'paperdrawer-title',
    super.key,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> slivers;
  final ScrollController? controller;
  final String heroTag;

  @override
  State<PdLargeTitleScaffold> createState() => _PdLargeTitleScaffoldState();
}

class _PdLargeTitleScaffoldState extends State<PdLargeTitleScaffold> {
  bool _scrolled = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Pd.bg,
    body: SafeArea(
      top: false,
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Pd.maxContent),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth != 0 ||
                  notification.metrics.axis != Axis.vertical) {
                return false;
              }
              final scrolled = notification.metrics.extentBefore > 0;
              if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
              return false;
            },
            child: CustomScrollView(
              controller: widget.controller,
              slivers: [
                CupertinoSliverNavigationBar(
                  padding: const EdgeInsetsDirectional.only(
                    start: Pd.margin,
                    end: Pd.margin,
                  ),
                  largeTitle: Text(widget.title),
                  middle: Text(widget.title),
                  trailing: widget.trailing,
                  automaticallyImplyLeading: false,
                  alwaysShowMiddle: false,
                  transitionBetweenRoutes: false,
                  heroTag: widget.heroTag,
                  backgroundColor: Pd.bg,
                  brightness: Brightness.dark,
                  automaticBackgroundVisibility: false,
                  enableBackgroundFilterBlur: false,
                  border: _scrolled
                      ? const Border(bottom: BorderSide(color: Pd.hairline))
                      : null,
                ),
                ...widget.slivers,
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: Pd.s12 + MediaQuery.paddingOf(context).bottom,
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

class PdPushedScaffold extends StatefulWidget {
  const PdPushedScaffold({
    required this.backLabel,
    this.kicker,
    this.title,
    this.titleStyle,
    this.backStyle,
    this.actions = const [],
    required this.children,
    this.bottom,
    this.onBack,
    this.glassBack = false,
    this.closeOnRight = false,
    this.controller,
    super.key,
  });

  final String backLabel;
  final String? kicker;
  final String? title;
  final TextStyle? titleStyle;
  final TextStyle? backStyle;
  final List<Widget> actions;
  final List<Widget> children;
  final Widget? bottom;
  final VoidCallback? onBack;
  final bool glassBack;
  final bool closeOnRight;
  final ScrollController? controller;

  @override
  State<PdPushedScaffold> createState() => _PdPushedScaffoldState();
}

class _PdPushedScaffoldState extends State<PdPushedScaffold> {
  bool _scrolled = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Pd.bg,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Pd.maxContent),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: _scrolled
                      ? const Border(bottom: BorderSide(color: Pd.hairline))
                      : null,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.glassBack || widget.closeOnRight
                        ? Pd.margin
                        : Pd.s3,
                  ),
                  child: Row(
                    children: [
                      if (widget.closeOnRight) ...[
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              widget.title ?? '',
                              style: widget.titleStyle ?? PdType.trackerTitle,
                            ),
                          ),
                        ),
                        const SizedBox(width: Pd.s3),
                        PdGlassIcon(
                          key: const ValueKey('close-button'),
                          label: widget.backLabel,
                          icon: const Icon(LucideIcons.x),
                          onPressed: widget.onBack,
                        ),
                      ] else ...[
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: widget.glassBack
                                ? PdGlassIcon(
                                    key: const ValueKey('back-button'),
                                    icon: Transform.flip(
                                      flipX:
                                          Directionality.of(context) ==
                                          TextDirection.rtl,
                                      child: const PdIcon(
                                        PdGlyph.back,
                                        size: Pd.s5,
                                        color: Pd.text,
                                      ),
                                    ),
                                    label: 'Back to ${widget.backLabel}',
                                    onPressed:
                                        widget.onBack ??
                                        () => Navigator.maybePop(context),
                                  )
                                : CupertinoButton(
                                    key: const ValueKey('back-button'),
                                    padding: const EdgeInsets.only(
                                      right: Pd.s2,
                                    ),
                                    minimumSize: const Size.square(Pd.tapMin),
                                    pressedOpacity: 0.7,
                                    focusColor: Pd.lime,
                                    onPressed:
                                        widget.onBack ??
                                        () {
                                          if (GoRouter.maybeOf(context)
                                              case final router?) {
                                            if (router.canPop()) router.pop();
                                          } else {
                                            Navigator.maybePop(context);
                                          }
                                        },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Transform.flip(
                                          flipX:
                                              Directionality.of(context) ==
                                              TextDirection.rtl,
                                          child: PdIcon(
                                            PdGlyph.back,
                                            color:
                                                widget.backStyle?.color ??
                                                Pd.lime,
                                            size: Pd.s5,
                                          ),
                                        ),
                                        const SizedBox(width: Pd.s1),
                                        Flexible(
                                          child: Text(
                                            widget.backLabel,
                                            style:
                                                widget.backStyle ??
                                                PdType.navBack.copyWith(
                                                  color: Pd.lime,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        ...widget.actions,
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.depth != 0 ||
                        notification.metrics.axis != Axis.vertical) {
                      return false;
                    }
                    final scrolled = notification.metrics.extentBefore > 0;
                    if (scrolled != _scrolled) {
                      setState(() => _scrolled = scrolled);
                    }
                    return false;
                  },
                  child: ListView(
                    controller: widget.controller,
                    padding: const EdgeInsets.fromLTRB(
                      Pd.margin,
                      Pd.s3,
                      Pd.margin,
                      Pd.s6,
                    ),
                    children: [
                      if (widget.kicker case final kicker?) ...[
                        Text(
                          kicker,
                          style: PdType.label.copyWith(color: Pd.textMuted),
                        ),
                        const SizedBox(height: Pd.s2),
                      ],
                      if (!widget.closeOnRight && widget.title != null) ...[
                        Semantics(
                          header: true,
                          child: Text(
                            widget.title!,
                            style: widget.titleStyle ?? PdType.title1,
                          ),
                        ),
                        const SizedBox(height: Pd.s5),
                      ],
                      ...widget.children,
                    ],
                  ),
                ),
              ),
              if (widget.bottom case final bottom?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Pd.margin,
                    Pd.s2,
                    Pd.margin,
                    Pd.s3,
                  ),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ScanButton extends StatelessWidget {
  const ScanButton({required this.onTap, this.onLongPress, super.key});

  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Scan or add a document',
    button: true,
    onTap: onTap,
    onLongPress: onLongPress,
    excludeSemantics: true,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(Pd.appbarIos),
      pressedOpacity: 0.7,
      focusColor: Pd.lime,
      onPressed: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(minHeight: Pd.s8 + Pd.s1),
        padding: const EdgeInsets.symmetric(horizontal: Pd.s3),
        decoration: BoxDecoration(
          color: Pd.lime,
          borderRadius: BorderRadius.circular(Pd.rMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PdIcon(PdGlyph.scan, size: Pd.iconSm, color: Pd.onLime),
            const SizedBox(width: Pd.s2),
            Text(
              'Scan',
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.4),
              style: PdType.bodyStrong.copyWith(color: Pd.onLime),
            ),
          ],
        ),
      ),
    ),
  );
}

class PdNavIcon extends StatelessWidget {
  const PdNavIcon({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    super.key,
  });

  final Widget icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    onTap: onTap,
    excludeSemantics: true,
    child: CupertinoButton(
      onPressed: onTap,
      minimumSize: const Size.square(Pd.tapMin),
      padding: EdgeInsets.zero,
      pressedOpacity: 0.7,
      focusColor: Pd.lime,
      child: IconTheme.merge(
        data: const IconThemeData(color: Pd.lime, size: Pd.iconMd),
        child: icon,
      ),
    ),
  );
}
