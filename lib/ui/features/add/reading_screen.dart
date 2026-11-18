import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/services/text_recognizer.dart';
import '../../../data/services/today.dart';
import '../../../domain/bill_reader.dart';
import '../../../domain/models/item.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/paper.dart';
import 'add_details_args.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({required this.files, super.key});

  final List<PendingFile> files;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  static const _readingBudget = Duration(seconds: 3);

  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_leaving) unawaited(_read());
    });
  }

  Future<void> _read() async {
    final recognizer = context.read<TextRecognizer>();
    final today = context.read<Today>().value;
    final pages = <String, List<String>>{};
    final work = Future.wait<void>(
      widget.files.map((file) async {
        try {
          pages[file.path] = await recognizer.recognize(file.path);
        } catch (_) {
          // An unreadable original still belongs in the drawer.
        }
      }),
    );
    final animationTime = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Pd.sheetDuration;
    await Future.wait<void>([
      work.then<void>((_) {}).timeout(_readingBudget, onTimeout: () {}),
      Future<void>.delayed(animationTime),
    ]);
    if (!mounted || _leaving) return;
    final lines = widget.files.expand(
      (file) => pages[file.path] ?? const <String>[],
    );
    final reading = readBill(lines.toList(), today: today);
    _continue(reading.isEmpty ? null : reading);
  }

  void _continue([ScanReading? reading]) {
    if (_leaving) return;
    _leaving = true;
    context.pushReplacement(
      Routes.details,
      extra: AddDetailsArgs(
        files: widget.files,
        reading: reading,
        kind: reading?.kind ?? ItemKind.bill,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Pd.bg,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Pd.maxContent),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Pd.margin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: -Pd.s6, end: 0),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : Pd.sheetDuration,
                    curve: Curves.easeOutCubic,
                    builder: (context, offset, child) => Transform.translate(
                      offset: Offset(0, offset),
                      child: child,
                    ),
                    child: ReceiptPaper(
                      padding: const EdgeInsets.all(Pd.s6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: PaperDrawerMark(),
                          ),
                          const SizedBox(height: Pd.s4),
                          Text(
                            'READING YOUR BILL',
                            style: PdType.label.copyWith(color: Pd.inkMuted),
                          ),
                          const SizedBox(height: Pd.s3),
                          const DashedRule(color: Pd.paperDash),
                          const SizedBox(height: Pd.s4),
                          Text(
                            'Looking for dates and details…',
                            style: PdType.cardTitle.copyWith(color: Pd.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Pd.s8),
                PdButton.text(
                  key: const ValueKey('reading-enter-manually'),
                  label: 'Enter details myself',
                  onPressed: _continue,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
