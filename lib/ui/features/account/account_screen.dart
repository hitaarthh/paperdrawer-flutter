import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/text_field.dart';
import 'account_widgets.dart';
import 'shared_session.dart';

/// Sign in and Create account for the shared build, as two tabs of one
/// screen. Signing in (or a sign-up that needs no confirmation) changes the
/// account, and the shared router redirects to the vault.
class AccountScreen extends StatefulWidget {
  const AccountScreen({
    required this.session,
    this.startCreating = false,
    super.key,
  });
  final SharedSession session;

  /// Opens on "Create account" instead of "Sign in".
  final bool startCreating;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const _minPassword = 8;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  late bool _creating = widget.startCreating;
  bool _busy = false;
  String? _error;

  /// The address a confirmation link went to, once sign-up needs one.
  String? _sentTo;

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
        (_creating &&
            (password.length < _minPassword || _name.text.trim().isEmpty))) {
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
          setState(() => _sentTo = email);
        }
      } else {
        await widget.session.account.signIn(email, password);
      }
      TextInput.finishAutofillContext();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = _authError(error.code));
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

  String _authError(String? code) => switch (code) {
    'email_not_confirmed' => 'Confirm your email first, then sign in.',
    'invalid_credentials' => 'That email or password didn’t match.',
    'user_already_exists' || 'email_exists' =>
      'An account with this email already exists. Sign in instead.',
    'weak_password' => 'That password is too weak. Use at least 8 characters with a number or symbol.',
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      'Too many attempts. Wait a moment and try again.',
    _ =>
      'Couldn’t ${_creating ? 'create your account' : 'sign in'}. Check your details and try again.',
  };

  Future<void> _openWeb(String path, String failure) async {
    try {
      await widget.session.openWeb(path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = failure);
    }
  }

  void _switch(bool creating) {
    _password.clear();
    setState(() {
      _creating = creating;
      _sentTo = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PdBrandBar(),
        Expanded(
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Pd.maxContent),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    Pd.margin,
                    Pd.s3,
                    Pd.margin,
                    Pd.margin,
                  ),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: Pd.s5,
                      children: _sentTo == null
                          ? _form()
                          : _checkEmail(_sentTo!),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  List<Widget> _form() => [
    AccountTabs(creating: _creating, enabled: !_busy, onChanged: _switch),
    AccountHeading(
      title: _creating ? 'Start your vault' : 'Open your vault',
      body: Text(
        _creating
            ? 'Takes a minute. Your first item takes another.'
            : 'Welcome back. Your bills are where you left them.',
      ),
    ),
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Pd.s4,
      children: [
        if (_creating)
          PdTextField(
            key: const ValueKey('account-name-field'),
            label: 'Your name',
            controller: _name,
            hint: 'What should we call you?',
            autofillHints: const [AutofillHints.name],
            enabled: !_busy,
            fieldKey: const ValueKey('account-name'),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (value) =>
                value.trim().isEmpty ? 'Enter your name.' : null,
          ),
        PdTextField(
          key: const ValueKey('account-email-field'),
          label: 'Email',
          controller: _email,
          fieldKey: const ValueKey('account-email'),
          hint: 'you@example.com',
          help: _creating ? 'Reminders are sent here.' : null,
          enabled: !_busy,
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          validator: (value) => value.trim().contains('@')
              ? null
              : 'Enter an email like you@example.com.',
        ),
        PdTextField(
          key: const ValueKey('account-password-field'),
          label: 'Password',
          controller: _password,
          fieldKey: const ValueKey('account-password'),
          hint: _creating ? '8+ characters' : 'Your password',
          help: _creating
              ? '8+ characters. A number or symbol makes it stronger.'
              : null,
          enabled: !_busy,
          obscureText: true,
          textCapitalization: TextCapitalization.none,
          autofillHints: [
            _creating ? AutofillHints.newPassword : AutofillHints.password,
          ],
          validator: _creating
              ? (value) => value.length < _minPassword
                    ? 'Use at least 8 characters.'
                    : null
              : null,
        ),
        if (_error case final error?)
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              key: const ValueKey('account-error'),
              style: PdType.callout.copyWith(color: Pd.signal),
            ),
          ),
        PdButton.primary(
          key: const ValueKey('account-submit'),
          label: _creating ? 'Create account' : 'Sign in',
          expand: true,
          busy: _busy,
          onPressed: _busy ? null : _submit,
        ),
        if (!_creating)
          PdButton.text(
            key: const ValueKey('account-reset'),
            label: 'Reset password on web',
            onPressed: _busy
                ? null
                : () => _openWeb('/signin', 'Couldn’t open the reset page.'),
          ),
      ],
    ),
    if (_creating) const AccountPromises(),
    AccountLegalLine(
      onTerms: _busy
          ? null
          : () => _openWeb('/terms', 'Couldn’t open the Terms.'),
      onPrivacy: _busy
          ? null
          : () => _openWeb('/privacy', 'Couldn’t open the Privacy policy.'),
    ),
  ];

  List<Widget> _checkEmail(String email) => [
    AccountHeading(
      title: 'Check your email',
      body: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'We sent a confirmation link to '),
            TextSpan(
              text: email,
              style: PdType.callout.copyWith(
                color: Pd.text,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation.weight(600)],
              ),
            ),
            const TextSpan(
              text: '. Open it to activate your vault, then come back here to sign in. Didn’t get it? Check your spam folder.',
            ),
          ],
        ),
      ),
    ),
    PdButton.primary(
      key: const ValueKey('account-back-to-sign-in'),
      label: 'Back to sign in',
      expand: true,
      onPressed: () => _switch(false),
    ),
  ];
}
