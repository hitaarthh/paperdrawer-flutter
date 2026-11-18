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
import '../../core/widgets/icons.dart';
import '../../core/widgets/snackbar.dart';
import 'add_details_args.dart';
import 'add_flow.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

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
          setState(() => _session = null);
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

  void _finish(List<PendingFile> files) {
    context.pushReplacement(Routes.reading, extra: List<PendingFile>.of(files));
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
                    children: [
                      PdButton.text(label: 'Cancel', onPressed: _close),
                      const Spacer(),
                      PdButton.text(
                        key: const ValueKey('capture-done'),
                        label: 'Done',
                        onPressed: _pages.isEmpty || _taking
                            ? null
                            : () => _finish(_pages),
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
                    Text(
                      _pages.isEmpty
                          ? 'Fit the whole document in the frame.'
                          : '${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'} captured',
                      textAlign: TextAlign.center,
                      style: PdType.callout.copyWith(color: Pd.textMuted),
                    ),
                    const SizedBox(height: Pd.s4),
                    _Shutter(
                      onTap: session == null || _taking ? null : _takePicture,
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
            const Center(
              child: ExcludeSemantics(
                child: PdIcon(
                  PdGlyph.scan,
                  size: Pd.s12 + Pd.s4,
                  color: Pd.lime,
                ),
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

class _Shutter extends StatelessWidget {
  const _Shutter({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: 'Take a photo',
    child: Material(
      color: onTap == null ? Pd.surface3 : Pd.lime,
      shape: const CircleBorder(),
      child: InkWell(
        key: const ValueKey('capture-shutter'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: Pd.controlH + Pd.s5,
          child: Icon(
            LucideIcons.camera,
            size: Pd.iconMd,
            color: onTap == null ? Pd.textSubtle : Pd.onLime,
          ),
        ),
      ),
    ),
  );
}
