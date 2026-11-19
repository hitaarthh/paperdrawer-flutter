import 'dart:ui' show ImageFilter;

import 'package:cupertino_ui/cupertino_ui.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';
import 'icons.dart';

class PdTabBar extends StatelessWidget {
  const PdTabBar({
    required this.currentIndex,
    required this.onTap,
    required this.onScan,
    this.onScanLongPress,
    this.claimsBadge = 0,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onScan;
  final VoidCallback? onScanLongPress;
  final int claimsBadge;

  static final _blur = ImageFilter.blur(
    sigmaX: Pd.dockBlur,
    sigmaY: Pd.dockBlur,
  );
  static const _radius = BorderRadius.all(Radius.circular(Pd.rPill));
  static const _tabs = [
    ('Vault', PdGlyph.vault),
    ('Claims', PdGlyph.claims),
    ('Settings', PdGlyph.settings),
  ];

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final highContrast = MediaQuery.highContrastOf(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.symmetric(horizontal: Pd.s4),
      child: Padding(
        padding: const EdgeInsets.only(bottom: Pd.s2),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Pd.dockMaxWidth),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                borderRadius: _radius,
                boxShadow: Pd.shadowFab,
              ),
              child: ClipRRect(
                borderRadius: _radius,
                child: BackdropFilter(
                  enabled: !highContrast,
                  filter: _blur,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: highContrast ? Pd.surface1 : null,
                      gradient: highContrast
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Pd.dockGlassTop, Pd.dockGlassBottom],
                            ),
                      borderRadius: _radius,
                    ),
                    child: CustomPaint(
                      foregroundPainter: _DockRim(highContrast),
                      child: Padding(
                        padding: const EdgeInsets.all(Pd.s1),
                        child: Stack(
                          children: [
                            Positioned.fill(child: _selection(context)),
                            _controls(),
                          ],
                        ),
                      ),
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

  Widget _selection(BuildContext context) => AnimatedAlign(
    alignment: AlignmentDirectional(-1 + 2 * currentIndex / _tabs.length, 0),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Pd.dockSelectionDuration,
    curve: Curves.easeOutCubic,
    child: FractionallySizedBox(
      widthFactor: 1 / (_tabs.length + 1),
      heightFactor: 1,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Pd.dockSelection,
          borderRadius: _radius,
        ),
      ),
    ),
  );

  Widget _controls() => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, (title, glyph)) in _tabs.indexed)
          Expanded(
            child: _DockButton(
              key: ValueKey('${title.toLowerCase()}-tab'),
              title: title,
              glyph: glyph,
              selected: index == currentIndex,
              badge: glyph == PdGlyph.claims ? claimsBadge : 0,
              onTap: () => onTap(index),
            ),
          ),
        Expanded(
          child: _DockButton(
            key: const ValueKey('scan-or-add'),
            title: 'Scan or add',
            glyph: PdGlyph.scan,
            onTap: onScan,
            onLongPress: onScanLongPress,
          ),
        ),
      ],
    ),
  );
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.title,
    required this.glyph,
    required this.onTap,
    this.selected,
    this.badge = 0,
    this.onLongPress,
    super.key,
  });

  final String title;
  final PdGlyph glyph;
  final bool? selected;
  final int badge;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scan = glyph == PdGlyph.scan;
    final accent = selected == true || (scan && onTap != null);
    return Semantics(
      label: badge > 0 ? '$title, $badge need action' : title,
      selected: selected,
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scan && onTap != null ? Pd.limeTint : null,
          borderRadius: PdTabBar._radius,
        ),
        child: CupertinoButton(
          minimumSize: const Size(Pd.tapMin, Pd.controlH),
          padding: const EdgeInsets.all(Pd.s1),
          borderRadius: PdTabBar._radius,
          pressedOpacity: 0.7,
          focusColor: Pd.lime,
          onPressed: onTap,
          onLongPress: onLongPress,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: Pd.s1,
            children: [
              PdIcon(glyph, color: accent ? Pd.lime : Pd.text2),
              Text.rich(
                TextSpan(
                  text: scan ? title : title.toUpperCase(),
                  children: [
                    if (badge > 0)
                      TextSpan(
                        text: ' $badge',
                        style: const TextStyle(color: Pd.signal),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: PdType.tabLabel.copyWith(
                  color: scan && accent
                      ? Pd.lime
                      : onTap == null
                      ? Pd.textSubtle
                      : Pd.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockRim extends CustomPainter {
  const _DockRim(this.highContrast);

  final bool highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Pd.line;
    if (!highContrast) {
      paint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Pd.dockRimLight, Pd.dockRimShade, Pd.dockRimLight],
      ).createShader(rect);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(Pd.rPill),
      ).scaleRadii().deflate(paint.strokeWidth / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DockRim oldDelegate) =>
      oldDelegate.highContrast != highContrast;
}
