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
}) => _presentSheet<T>(
  context,
  padding: const EdgeInsets.fromLTRB(Pd.margin, Pd.s2, Pd.margin, Pd.s4),
  builder: (context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      const _Grabber(),
      const SizedBox(height: Pd.s4),
      Semantics(header: true, child: Text(title, style: PdType.title2)),
      if (subtitle != null) ...[
        const SizedBox(height: Pd.s1),
        Text(subtitle, style: PdType.callout.copyWith(color: Pd.textMuted)),
      ],
      const SizedBox(height: Pd.s3),
      for (final option in options) _OptionRow(option: option),
      ?body,
    ],
  ),
);

/// A sheet whose content the caller composes (the Add sheet). The kit still
/// owns the surface, grabber, scrim, safe area, keyboard inset and scrolling.
/// The content sits [Pd.s4] below the grabber, and ends at the home indicator
/// or [Pd.s4] above the screen edge, whichever is higher. Pop the sheet's own
/// navigator (`Navigator.pop(context, value)`) to return a value.
Future<T?> showPdCustomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? semanticLabel,
}) => _presentSheet<T>(
  context,
  padding: const EdgeInsets.fromLTRB(Pd.margin, Pd.s2, Pd.margin, 0),
  bottomMinimum: Pd.s4,
  semanticLabel: semanticLabel,
  builder: (context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      const _Grabber(),
      const SizedBox(height: Pd.s4),
      Builder(builder: builder),
    ],
  ),
);

Future<T?> _presentSheet<T>(
  BuildContext context, {
  required EdgeInsets padding,
  required WidgetBuilder builder,
  double bottomMinimum = 0,
  String? semanticLabel,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  backgroundColor: CupertinoColors.transparent,
  barrierColor: Pd.scrim,
  constraints: const BoxConstraints(maxWidth: Pd.maxContent),
  builder: (context) {
    Widget sheet = Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _SheetSurface(
        bottomMinimum: bottomMinimum,
        child: SingleChildScrollView(
          padding: padding,
          child: Builder(builder: builder),
        ),
      ),
    );
    if (semanticLabel != null) {
      sheet = Semantics(
        container: true,
        explicitChildNodes: true,
        label: semanticLabel,
        child: sheet,
      );
    }
    return sheet;
  },
);

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child, this.bottomMinimum = 0});

  final Widget child;

  /// Space kept below the content when there is no home indicator.
  final double bottomMinimum;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Pd.surface2,
      borderRadius: BorderRadius.vertical(top: Radius.circular(Pd.rLg)),
      boxShadow: Pd.shadowSheet,
    ),
    child: SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: bottomMinimum),
      child: child,
    ),
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
  final candidate = initial ?? context.read<Today?>()?.value;
  final fallbackClock = candidate == null ? Today() : null;
  var selected = civil(candidate ?? fallbackClock!.value);
  fallbackClock?.dispose();
  if (earliest != null && selected.isBefore(earliest)) selected = earliest;
  if (latest != null && selected.isAfter(latest)) selected = latest;

  // The native wheel uses local time, while the date-only API uses civil dates.
  DateTime local(DateTime date) => DateTime(date.year, date.month, date.day);
  return _showPdDateWheel(
    context,
    title: title,
    mode: CupertinoDatePickerMode.date,
    initial: local(selected),
    min: earliest == null ? null : local(earliest),
    max: latest == null ? null : local(latest),
  ).then((date) => date == null ? null : civil(date));
}

Future<DateTime?> showPdFollowUpPicker(
  BuildContext context, {
  required DateTime now,
  DateTime? initial,
  String title = 'Follow-up reminder',
}) {
  final earliest = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute + 1,
  );
  final tomorrow = DateTime(now.year, now.month, now.day + 1, 10);
  return _showPdDateWheel(
    context,
    title: title,
    mode: CupertinoDatePickerMode.dateAndTime,
    initial: initial != null && !initial.isBefore(earliest)
        ? initial.toLocal()
        : tomorrow,
    min: earliest,
  );
}

Future<DateTime?> _showPdDateWheel(
  BuildContext context, {
  required String title,
  required CupertinoDatePickerMode mode,
  required DateTime initial,
  DateTime? min,
  DateTime? max,
}) {
  var selected = initial;
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
              Flexible(
                child: SizedBox(
                  height: Pd.s12 * 5,
                  child: CupertinoDatePicker(
                    mode: mode,
                    dateOrder: DatePickerDateOrder.dmy,
                    backgroundColor: Pd.surface2,
                    initialDateTime: initial,
                    minimumDate: min,
                    maximumDate: max,
                    minimumYear: min?.year ?? 1,
                    maximumYear: max?.year,
                    onDateTimeChanged: (date) => selected = date,
                  ),
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
