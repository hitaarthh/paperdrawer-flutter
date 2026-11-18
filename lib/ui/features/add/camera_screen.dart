import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/services/capture_service.dart';
import '../../../domain/models/item.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/snackbar.dart';
import 'add_details_args.dart';
import 'add_flow.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({this.kind, super.key});

  final ItemKind? kind;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final _pages = <PendingFile>[];
  CaptureSession? _session;
  Future<void>? _closing;
  bool _active = true;
  bool _starting = false;
  bool _taking = false;
  bool _torch = false;
  bool _changingTorch = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _active = true;
        if (_error == null) unawaited(_open());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _active = false;
        final session = _session;
        if (session != null) {
          setState(() {
            _session = null;
            _torch = false;
          });
          _closing = _closeQuietly(session);
        }
    }
  }

  Future<void> _open() async {
    if (_starting || _session != null) return;
    final capture = context.read<CaptureService>();
    _starting = true;
    _error = null;
    try {
      await _closing;
      if (!mounted || !_active) return;
      final session = await capture.openCamera();
      if (!mounted || !_active) {
        await _closeQuietly(session);
        return;
      }
      _session = session;
    } on FormatException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'The camera couldn’t open. Choose a photo or PDF.';
    } finally {
      _starting = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _takePicture() async {
    final session = _session;
    if (_taking || session == null) return;
    setState(() => _taking = true);
    try {
      final page = await session.takePicture();
      if (!mounted) return;
      setState(() => _pages.add(page));
    } catch (_) {
      if (mounted && _active) {
        showPdSnackbar(context, 'The photo couldn’t be taken. Try again.');
      }
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  Future<void> _pick() async {
    final files = await AddFlow.chooseOriginals(context);
    if (!mounted || files.isEmpty) return;
    _finish([..._pages, ...files]);
  }

  Future<void> _toggleTorch() async {
    final session = _session;
    if (session == null || _changingTorch || _taking) return;
    final enabled = !_torch;
    setState(() => _changingTorch = true);
    try {
      await session.setTorch(enabled);
      if (!mounted || _session != session) return;
      setState(() => _torch = enabled);
    } catch (_) {
      if (mounted && _session == session) {
        showPdSnackbar(context, 'The flash isn’t available on this camera.');
      }
    } finally {
      if (mounted) setState(() => _changingTorch = false);
    }
  }

  void _finish(List<PendingFile> files) {
    context.pushReplacement(
      Routes.reading,
      extra: CaptureReadingArgs(List.of(files), kind: widget.kind),
    );
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.vault);
    }
  }

  Future<void> _closeQuietly(CaptureSession session) async {
    try {
      await session.close();
    } catch (_) {
      // Camera resources can already be released when iOS backgrounds the app.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final session = _session;
    if (session != null) unawaited(_closeQuietly(session));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      backgroundColor: Pd.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Pd.maxContent),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Pd.margin),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    spacing: Pd.s2,
                    children: [
                      _CameraButton(
                        key: const ValueKey('capture-close'),
                        icon: LucideIcons.x,
                        label: 'Close camera',
                        onTap: _close,
                      ),
                      Flexible(
                        child: _CameraCaption(
                          widget.kind == null || widget.kind == ItemKind.bill
                              ? 'BILL & WARRANTY'
                              : widget.kind!.chip,
                        ),
                      ),
                      _CameraButton(
                        key: const ValueKey('capture-flash'),
                        icon: _torch ? LucideIcons.zap : LucideIcons.zapOff,
                        label: _torch ? 'Turn flash off' : 'Turn flash on',
                        onTap: session == null || _taking || _changingTorch
                            ? null
                            : _toggleTorch,
                        selected: _torch,
                      ),
                    ],
                  ),
                  const SizedBox(height: Pd.s4),
                  Expanded(
                    child: _error != null
                        ? Center(
                            child: SingleChildScrollView(
                              child: DashedTile(
                                title: 'Camera unavailable',
                                body: _error!,
                                action: Column(
                                  children: [
                                    PdButton.primary(
                                      label: 'Choose a photo or PDF',
                                      onPressed: _pick,
                                      expand: true,
                                    ),
                                    PdButton.text(
                                      label: 'Type it in',
                                      onPressed: () => context.pushReplacement(
                                        Routes.details,
                                        extra: AddDetailsArgs(
                                          files: List.of(_pages),
                                          kind: widget.kind ?? ItemKind.bill,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : _CameraStage(session: session),
                  ),
                  if (_error == null) ...[
                    const SizedBox(height: Pd.s6),
                    _CameraCaption(
                      _pages.isEmpty
                          ? 'FILL THE FRAME · FADED BILLS WORK TOO'
                          : '${_pages.length} ${_pages.length == 1 ? 'PAGE' : 'PAGES'} CAPTURED',
                    ),
                    const SizedBox(height: Pd.s4),
                    Row(
                      spacing: Pd.s2,
                      children: [
                        Expanded(
                          child: Center(
                            child: _CameraButton(
                              key: const ValueKey('capture-upload'),
                              icon: LucideIcons.upload,
                              label: 'Upload',
                              showLabel: true,
                              onTap: _taking ? null : _pick,
                            ),
                          ),
                        ),
                        _Shutter(
                          onTap: session == null || _taking
                              ? null
                              : _takePicture,
                        ),
                        Expanded(
                          child: PdButton.text(
                            key: const ValueKey('capture-done'),
                            label: 'Done',
                            onPressed: _pages.isEmpty || _taking
                                ? null
                                : () => _finish(_pages),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: Pd.s6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraStage extends StatelessWidget {
  const _CameraStage({required this.session});

  final CaptureSession? session;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Pd.surface1,
        borderRadius: BorderRadius.circular(Pd.rMd),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Pd.rMd),
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            if (session != null) Center(child: session!.buildPreview()),
            const Padding(
              padding: EdgeInsets.all(Pd.s4),
              child: IgnorePointer(
                child: CustomPaint(painter: _FramePainter()),
              ),
            ),
            if (session == null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(Pd.s4),
                  child: Text('Opening camera…', style: PdType.callout),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraCaption extends StatelessWidget {
  const _CameraCaption(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Pd.surface2,
      borderRadius: BorderRadius.circular(Pd.rSm),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: Pd.s3, vertical: Pd.s2),
      child: Text(label, style: PdType.label, textAlign: TextAlign.center),
    ),
  );
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.showLabel = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool showLabel;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    isSelected: selected,
    style: IconButton.styleFrom(
      backgroundColor: showLabel ? Pd.bg : Pd.surface2,
      foregroundColor: selected ? Pd.lime : Pd.text,
      minimumSize: const Size.square(Pd.tapMin),
    ),
    icon: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: Pd.iconMd),
        if (showLabel) ...[
          const SizedBox(height: Pd.s1),
          Text(label.toUpperCase(), style: PdType.tabLabel),
        ],
      ],
    ),
  );
}

class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = Pd.lime
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final (x, y, dx, dy) in [
      (0.0, 0.0, 1, 1),
      (size.width, 0.0, -1, 1),
      (0.0, size.height, 1, -1),
      (size.width, size.height, -1, -1),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + Pd.s8 * dy)
          ..lineTo(x, y)
          ..lineTo(x + Pd.s8 * dx, y),
        pen,
      );
    }
    canvas.drawLine(
      Offset(Pd.s3, size.height * 0.4),
      Offset(size.width - Pd.s3, size.height * 0.4),
      pen..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => false;
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: 'Take a photo',
    onTap: onTap,
    child: Material(
      color: Pd.bg,
      shape: CircleBorder(
        side: BorderSide(color: onTap == null ? Pd.line : Pd.lime, width: 3),
      ),
      child: InkWell(
        key: const ValueKey('capture-shutter'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: Pd.controlH + Pd.s6,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onTap == null ? Pd.surface3 : Pd.lime,
              ),
              child: const SizedBox.square(dimension: Pd.s12 + Pd.s3),
            ),
          ),
        ),
      ),
    ),
  );
}
