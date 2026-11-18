import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/text_field.dart';
import 'shared_session.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({required this.session, super.key});
  final SharedSession session;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  String? _error;
  bool _checkEmail = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') ||
        password.isEmpty ||
        (_creating && (password.length < 8 || _name.text.trim().isEmpty))) {
      setState(
        () => _error = _creating
            ? 'Enter your name, a valid email and at least 8 characters for your password.'
            : 'Enter your email and password.',
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_creating) {
        final signedIn = await widget.session.account.signUp(
          _name.text.trim(),
          email,
          password,
        );
        if (!mounted) return;
        if (!signedIn) {
          _password.clear();
          setState(() => _checkEmail = true);
        }
      } else {
        await widget.session.account.signIn(email, password);
      }
      TextInput.finishAutofillContext();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = switch (error.code) {
          'email_not_confirmed' => 'Confirm your email first, then sign in.',
          'invalid_credentials' => 'That email or password didn’t match.',
          'over_email_send_rate_limit' || 'over_request_rate_limit' =>
            'Too many attempts. Wait a moment and try again.',
          _ =>
            'Couldn’t ${_creating ? 'create your account' : 'sign in'}. Check your details and try again.',
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'Couldn’t reach PaperDrawer. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    try {
      await widget.session.openWeb('/signin');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Couldn’t open the reset page.');
    }
  }

  void _switch(bool creating) {
    _password.clear();
    setState(() {
      _creating = creating;
      _checkEmail = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Pd.maxContent),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(Pd.margin),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                spacing: Pd.s4,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: PaperDrawerMark(size: Pd.s10),
                  ),
                  Text(
                    _checkEmail
                        ? 'Check your email'
                        : 'Never lose a claim to a missing bill.',
                    style: PdType.title1,
                  ),
                  Text(
                    _checkEmail
                        ? 'Open the confirmation from PaperDrawer, then return here to sign in.'
                        : 'Open the same bills and claims you keep on PaperDrawer web.',
                    style: PdType.callout.copyWith(color: Pd.textMuted),
                  ),
                  if (_checkEmail)
                    PdButton.primary(
                      label: 'Back to sign in',
                      onPressed: () => _switch(false),
                    )
                  else ...[
                    if (_creating)
                      PdTextField(
                        label: 'Name',
                        controller: _name,
                        autofillHints: const [AutofillHints.name],
                        enabled: !_busy,
                        fieldKey: const ValueKey('account-name'),
                        textInputAction: TextInputAction.next,
                      ),
                    PdTextField(
                      label: 'Email',
                      controller: _email,
                      fieldKey: const ValueKey('account-email'),
                      hint: 'you@example.com',
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.none,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                    ),
                    PdTextField(
                      label: 'Password',
                      controller: _password,
                      fieldKey: const ValueKey('account-password'),
                      enabled: !_busy,
                      obscureText: true,
                      help: _creating ? 'Use at least 8 characters.' : null,
                      textCapitalization: TextCapitalization.none,
                      autofillHints: [
                        _creating
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                    ),
                    if (_error case final error?)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: PdType.callout.copyWith(color: Pd.signal),
                        ),
                      ),
                    PdButton.primary(
                      key: const ValueKey('account-submit'),
                      label: _creating ? 'Create account' : 'Sign in',
                      busy: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                    if (!_creating)
                      PdButton.text(
                        label: 'Reset password on web',
                        onPressed: _busy ? null : _reset,
                      ),
                    PdButton.text(
                      label: _creating
                          ? 'Already have an account? Sign in'
                          : 'Create an account',
                      onPressed: _busy ? null : () => _switch(!_creating),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
