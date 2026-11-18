import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';

class PdTextField extends StatefulWidget {
  const PdTextField({
    required this.label,
    required this.controller,
    this.hint,
    this.readFromBill = false,
    this.help,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.onChanged,
    this.prefixText,
    this.textCapitalization = TextCapitalization.sentences,
    this.fieldKey,
    this.enabled = true,
    this.obscureText = false,
    this.autofillHints,
    this.suffix,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool readFromBill;
  final String? help;
  final String? Function(String)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final String? prefixText;
  final TextCapitalization textCapitalization;
  final Key? fieldKey;
  final bool enabled;
  final bool obscureText;
  final Iterable<String>? autofillHints;

  /// Trailing control inside the field (for example a SHOW/HIDE toggle).
  /// When set, it replaces the clear button.
  final Widget? suffix;

  @override
  State<PdTextField> createState() => _PdTextFieldState();
}

class _PdTextFieldState extends State<PdTextField> {
  final _focus = FocusNode();
  bool _wasFocused = false;
  bool _blurred = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(PdTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  void _onFocusChanged() {
    setState(() {
      if (_focus.hasFocus) {
        _wasFocused = true;
      } else if (_wasFocused) {
        _blurred = true;
      }
    });
  }

  void _onTextChanged() {
    if (_blurred && widget.validator != null) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _blurred
        ? widget.validator?.call(widget.controller.text)
        : null;
    final help =
        error ??
        widget.help ??
        (widget.readFromBill
            ? 'Check it against your bill before saving.'
            : null);
    final borderColor = error != null
        ? Pd.signal
        : (_focus.hasFocus ? Pd.lime : Pd.line);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label: widget.label, readFromBill: widget.readFromBill),
        const SizedBox(height: Pd.s2),
        Semantics(
          label: widget.label,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Pd.controlH),
            child: CupertinoTextField(
              key: widget.fieldKey,
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              obscureText: widget.obscureText,
              autocorrect: !widget.obscureText,
              enableSuggestions: !widget.obscureText,
              autofillHints: widget.autofillHints,
              placeholder: widget.hint,
              placeholderStyle: PdType.body.copyWith(color: Pd.placeholder),
              style: PdType.body.copyWith(
                color: widget.enabled ? Pd.text : Pd.textSubtle,
              ),
              cursorColor: Pd.lime,
              padding: const EdgeInsets.symmetric(
                horizontal: Pd.s4,
                vertical: Pd.s3,
              ),
              prefix: widget.prefixText == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: Pd.s4),
                      child: Text(widget.prefixText!, style: PdType.body),
                    ),
              decoration: _fieldDecoration(
                borderColor,
                focused: _focus.hasFocus,
              ),
              suffix: widget.suffix == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: Pd.s1),
                      child: widget.suffix,
                    ),
              clearButtonMode: widget.suffix == null
                  ? OverlayVisibilityMode.editing
                  : OverlayVisibilityMode.never,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              textCapitalization: widget.textCapitalization,
              maxLines: widget.maxLines,
              onChanged: widget.onChanged,
            ),
          ),
        ),
        if (help != null) ...[
          const SizedBox(height: Pd.s1),
          Semantics(
            liveRegion: error != null,
            child: Text(
              help,
              style: PdType.footnote.copyWith(
                color: error == null ? Pd.textMuted : Pd.signal,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class PdFieldButton extends StatelessWidget {
  const PdFieldButton({
    required this.label,
    required this.value,
    this.hint,
    this.readFromBill = false,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final String? hint;
  final bool readFromBill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _FieldLabel(label: label, readFromBill: readFromBill),
      const SizedBox(height: Pd.s2),
      Semantics(
        label: label,
        child: CupertinoButton(
          onPressed: onTap,
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(Pd.tapMin),
          pressedOpacity: 0.7,
          focusColor: Pd.lime,
          child: Container(
            decoration: _fieldDecoration(Pd.line),
            constraints: const BoxConstraints(minHeight: Pd.controlH),
            padding: const EdgeInsets.symmetric(
              horizontal: Pd.s4,
              vertical: Pd.s3,
            ),
            child: Row(
              spacing: Pd.s2,
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? hint ?? 'Choose a date' : value,
                    style: PdType.body.copyWith(
                      color: value.isEmpty ? Pd.placeholder : Pd.text,
                    ),
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
        ),
      ),
      if (readFromBill) ...[
        const SizedBox(height: Pd.s1),
        Text(
          'Check it against your bill before saving.',
          style: PdType.footnote.copyWith(color: Pd.textMuted),
        ),
      ],
    ],
  );
}

BoxDecoration _fieldDecoration(Color border, {bool focused = false}) =>
    BoxDecoration(
      color: Pd.surface1,
      border: Border.all(color: border, width: focused ? 2 : 1),
      borderRadius: BorderRadius.circular(Pd.rSm),
    );

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.readFromBill});

  final String label;
  final bool readFromBill;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: Pd.s2,
    runSpacing: Pd.s1,
    children: [
      Text(
        label.toUpperCase(),
        style: PdType.label.copyWith(color: Pd.textMuted),
      ),
      if (readFromBill)
        Text('READ FROM BILL', style: PdType.label.copyWith(color: Pd.lime)),
    ],
  );
}
