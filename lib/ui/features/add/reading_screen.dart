import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/services/capture_service.dart';
import '../../../data/services/text_recognizer.dart';
import '../../../data/services/today.dart';
import '../../../domain/bill_reader.dart';
import '../../../domain/formats.dart';
import '../../../domain/models/item.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/paper.dart';
import 'add_details_args.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({required this.files, this.kind, super.key});

  final List<PendingFile> files;
  final ItemKind? kind;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  static const _readingBudget = Duration(seconds: 3);

  bool _leaving = false;
  ScanReading? _reading;
  late final Future<CaptureOriginal>? _original;

  @override
  void initState() {
    super.initState();
    final original = widget.files.firstOrNull;
    _original = original == null
        ? null
        : context.read<CaptureService>().inspect(original);
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
          if (!mounted || _leaving) return;
          setState(
            () => _reading = readBill(
              widget.files
                  .expand((file) => pages[file.path] ?? const <String>[])
                  .toList(),
              today: today,
            ),
          );
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
    if (_reading?.isEmpty == false && animationTime != Duration.zero) {
      await Future<void>.delayed(Pd.sheetDuration);
    }
    if (!mounted || _leaving) return;
    _continue();
  }

  void _continue() {
    if (_leaving) return;
    _leaving = true;
    context.pushReplacement(
      Routes.details,
      extra: AddDetailsArgs(
        files: widget.files,
        reading: _reading?.isEmpty == false ? _reading : null,
        kind: widget.kind ?? _reading?.kind ?? ItemKind.bill,
      ),
    );
  }

  void _cancel() {
    _leaving = true;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.vault);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Pd.bg,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Pd.maxContent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Pd.margin),
                  child: _content(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Pd.margin,
                  Pd.s2,
                  Pd.margin,
                  Pd.s4,
                ),
                child: Flex(
                  direction: isLargeText(context)
                      ? Axis.vertical
                      : Axis.horizontal,
                  spacing: Pd.s2,
                  children: isLargeText(context)
                      ? _actions()
                            .map(
                              (button) => SizedBox(
                                width: double.infinity,
                                child: button,
                              ),
                            )
                            .toList()
                      : _actions()
                            .map((button) => Expanded(child: button))
                            .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _actions() => [
    PdButton.secondary(
      key: const ValueKey('reading-cancel'),
      label: 'Cancel',
      onPressed: _cancel,
    ),
    PdButton.primary(
      key: const ValueKey('reading-enter-manually'),
      label: 'Skip to review',
      onPressed: _continue,
    ),
  ];

  Widget _content(BuildContext context) {
    final original = widget.files.firstOrNull;
    final reading = _reading;
    final header = widget.kind?.isDocument == true
        ? 'READING YOUR DOCUMENT'
        : 'READING YOUR BILL';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          original == null
              ? header
              : '$header · ${original.name.toUpperCase()}',
          style: PdType.label.copyWith(color: Pd.textMuted),
        ),
        const SizedBox(height: Pd.s4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Pd.s8),
          child: _ReadingPreview(future: _original),
        ),
        const SizedBox(height: Pd.s6),
        Semantics(
          header: true,
          child: Text('Reading it line by line…', style: PdType.title1),
        ),
        const SizedBox(height: Pd.s4),
        _ReadingRow('Store', reading?.source),
        _ReadingRow(
          'Date',
          reading?.startsOn == null ? null : monoDate(reading!.startsOn!),
        ),
        _ReadingRow('Product', reading?.name),
        _ReadingRow(
          'Total',
          reading?.amountMinor == null
              ? null
              : money(reading!.amountMinor!, 'INR'),
        ),
        _ReadingRow(
          'Warranty',
          reading?.warrantyMonths == null
              ? null
              : monthsLabel(reading!.warrantyMonths!),
        ),
        _ReadingRow('Reference', reading?.reference),
        _ReadingRow('Serial no.', reading?.serialNumber),
        const SizedBox(height: Pd.s4),
        Text(
          'Takes a few seconds. You’ll check every line before anything is saved.',
          style: PdType.footnote.copyWith(color: Pd.textMuted),
        ),
      ],
    );
  }
}

class _ReadingPreview extends StatelessWidget {
  const _ReadingPreview({required this.future});

  final Future<CaptureOriginal>? future;

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * 0.29).clamp(
      Pd.s12 * 3,
      Pd.s12 * 6,
    );
    final fallback = Center(
      child: Icon(LucideIcons.fileText, size: Pd.s10, color: Pd.inkMuted),
    );
    return ReceiptPaper(
      padding: const EdgeInsets.all(Pd.s3),
      child: SizedBox(
        height: height.toDouble(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder(
              future: future,
              builder: (context, snapshot) {
                final bytes = snapshot.data?.preview;
                return bytes == null
                    ? fallback
                    : Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        cacheWidth: 900,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => fallback,
                      );
              },
            ),
            if (!MediaQuery.disableAnimationsOf(context))
              TweenAnimationBuilder<double>(
                tween: Tween(begin: -1, end: 1),
                duration: _ReadingScreenState._readingBudget,
                builder: (context, y, child) =>
                    Align(alignment: Alignment(0, y), child: child),
                child: const ColoredBox(
                  color: Pd.lime,
                  child: SizedBox(height: 2, width: double.infinity),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: Pd.s8 + Pd.s1),
    padding: const EdgeInsets.symmetric(vertical: Pd.s2),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Pd.hairline)),
    ),
    child: Row(
      spacing: Pd.s3,
      children: [
        Icon(
          value == null ? LucideIcons.minus : LucideIcons.check,
          size: Pd.iconSm,
          color: value == null ? Pd.textSubtle : Pd.lime,
        ),
        Expanded(
          flex: 2,
          child: Text(
            label.toUpperCase(),
            style: PdType.label.copyWith(color: Pd.textMuted),
          ),
        ),
        Expanded(flex: 4, child: Text(value ?? '—', style: PdType.data)),
      ],
    ),
  );
}
