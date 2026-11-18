import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart' show showModalBottomSheet;
import 'package:provider/provider.dart';

import '../../../data/services/today.dart';
import '../../../domain/formats.dart';
import '../theme/tokens.dart';
import '../theme/type.dart';
import 'button.dart';
import 'icons.dart';

class PdSheetOption<T> {
  const PdSheetOption({
    required this.icon,
    this.glyph,
    required this.title,
    required this.description,
    required this.value,
    this.recommended = false,
  });

  final IconData? icon;
  final PdGlyph? glyph;
  final String title;
  final String description;
  final T value;
  final bool recommended;
}

Future<T?> showPdSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<PdSheetOption<T>> options = const [],
  Widget? body,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  backgroundColor: CupertinoColors.transparent,
  barrierColor: Pd.scrim,
  constraints: const BoxConstraints(maxWidth: Pd.maxContent),
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: _SheetSurface(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Pd.margin, Pd.s2, Pd.margin, Pd.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Grabber(),
            const SizedBox(height: Pd.s4),
            Semantics(header: true, child: Text(title, style: PdType.title2)),
            if (subtitle != null) ...[
              const SizedBox(height: Pd.s1),
              Text(
                subtitle,
                style: PdType.callout.copyWith(color: Pd.textMuted),
              ),
            ],
            const SizedBox(height: Pd.s3),
            for (final option in options) _OptionRow(option: option),
            ?body,
          ],
        ),
      ),
    ),
  ),
);

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Pd.surface2,
      borderRadius: BorderRadius.vertical(top: Radius.circular(Pd.rLg)),
      boxShadow: Pd.shadowSheet,
    ),
    child: SafeArea(top: false, child: child),
  );
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: Pd.s8 + Pd.s1,
      height: 5,
      decoration: BoxDecoration(
        color: Pd.line,
        borderRadius: BorderRadius.circular(Pd.rPill),
      ),
    ),
  );
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({required this.option});

  final PdSheetOption<T> option;

  @override
  Widget build(BuildContext context) {
    final foreground = option.recommended ? Pd.onLime : Pd.text;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Pd.hairline)),
      ),
      child: CupertinoButton(
        onPressed: () => Navigator.pop(context, option.value),
        padding: const EdgeInsets.symmetric(vertical: Pd.s2),
        minimumSize: const Size(0, Pd.s12 + Pd.s4),
        pressedOpacity: 0.7,
        focusColor: Pd.lime,
        child: Row(
          spacing: Pd.s3,
          children: [
            Container(
              width: Pd.appbarIos,
              height: Pd.appbarIos,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: option.recommended ? Pd.lime : Pd.surface3,
                borderRadius: BorderRadius.circular(Pd.rMd),
              ),
              child: switch (option.glyph) {
                final glyph? => PdIcon(glyph, color: foreground),
                null => Icon(option.icon, size: Pd.iconMd, color: foreground),
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.title, style: PdType.bodyStrong),
                  Text(
                    option.description,
                    style: PdType.footnote.copyWith(color: Pd.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: Pd.iconSm,
              color: Pd.textSubtle,
            ),
          ],
        ),
      ),
    );
  }
}

class PdAction<T> {
  const PdAction({
    required this.label,
    required this.value,
    this.destructive = false,
  });

  final String label;
  final T value;
  final bool destructive;
}

Future<T?> showPdActions<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<PdAction<T>> actions,
}) => showCupertinoModalPopup<T>(
  context: context,
  barrierColor: Pd.scrim,
  semanticsDismissible: true,
  builder: (context) => CupertinoActionSheet(
    title: title == null ? null : Text(title),
    message: message == null ? null : Text(message),
    actions: [
      for (final action in actions)
        CupertinoActionSheetAction(
          isDestructiveAction: action.destructive,
          onPressed: () => Navigator.pop(context, action.value),
          child: Text(action.label),
        ),
    ],
    cancelButton: CupertinoActionSheetAction(
      onPressed: () => Navigator.pop(context),
      child: const Text('Cancel'),
    ),
  ),
);

Future<bool> showPdConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async =>
    await showPdActions<bool>(
      context,
      title: title,
      message: message,
      actions: [
        PdAction(label: confirmLabel, value: true, destructive: destructive),
      ],
    ) ??
    false;

Future<DateTime?> showPdDatePicker(
  BuildContext context, {
  DateTime? initial,
  DateTime? min,
  DateTime? max,
  String title = 'Choose a date',
}) {
  final earliest = min == null ? null : civil(min);
  final latest = max == null ? null : civil(max);
  final fallbackClock = initial == null && context.read<Today?>() == null
      ? Today()
      : null;
  var selected = civil(
    initial ?? context.read<Today?>()?.value ?? fallbackClock!.value,
  );
  fallbackClock?.dispose();
  if (earliest != null && selected.isBefore(earliest)) selected = earliest;
  if (latest != null && selected.isAfter(latest)) selected = latest;

  return showCupertinoModalPopup<DateTime>(
    context: context,
    barrierColor: Pd.scrim,
    semanticsDismissible: true,
    builder: (context) => Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Pd.maxContent),
        child: _SheetSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(Pd.s3),
                child: Column(
                  children: [
                    const _Grabber(),
                    const SizedBox(height: Pd.s3),
                    Semantics(
                      header: true,
                      child: Text(title, style: PdType.title2),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: Pd.s12 * 5,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  dateOrder: DatePickerDateOrder.dmy,
                  backgroundColor: Pd.surface2,
                  initialDateTime: selected,
                  minimumDate: earliest,
                  maximumDate: latest,
                  minimumYear: earliest?.year ?? 1,
                  maximumYear: latest?.year,
                  onDateTimeChanged: (date) => selected = civil(date),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Pd.margin,
                  vertical: Pd.s2,
                ),
                child: PdButton.primary(
                  label: 'Done',
                  onPressed: () => Navigator.pop(context, selected),
                  expand: true,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
