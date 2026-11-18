import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SharedAccountConfig {
  const SharedAccountConfig(
    this.api,
    this.publishableKey,
    this.web, {
    this.confirmationOrigin,
  });

  final Uri api;
  final String publishableKey;
  final Uri web;
  final Uri? confirmationOrigin;

  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _web = String.fromEnvironment(
    'PAPERDRAWER_WEB_URL',
    defaultValue: 'https://paperdrawer.app',
  );
  static const _confirm = String.fromEnvironment('PAPERDRAWER_CONFIRM_ORIGIN');

  static bool get requested => _url.isNotEmpty || _key.isNotEmpty;

  factory SharedAccountConfig.fromEnvironment() {
    final api = Uri.tryParse(_url);
    final web = Uri.tryParse(_web);
    final confirmation = _confirm.isEmpty ? web : Uri.tryParse(_confirm);
    if (!_validOrigin(api) ||
        !_validOrigin(web) ||
        !_validOrigin(confirmation) ||
        !_isPublicKey(_key)) {
      throw const FormatException(
        'Set the Supabase URL, publishable key and PaperDrawer web URL.',
      );
    }
    return SharedAccountConfig(
      api!,
      _key,
      web!,
      confirmationOrigin: confirmation,
    );
  }

  static bool _validOrigin(Uri? uri) =>
      uri != null &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (uri.scheme == 'https' ||
          (kDebugMode && uri.scheme == 'http' && _localHost(uri.host)));

  static bool _localHost(String host) {
    if (host == 'localhost') return true;
    final address = InternetAddress.tryParse(host);
    if (address == null) return false;
    if (address.isLoopback) return true;
    final bytes = address.rawAddress;
    return bytes.length == 4 &&
        (bytes[0] == 10 ||
            (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
            (bytes[0] == 192 && bytes[1] == 168));
  }

  static bool _isPublicKey(String key) {
    if (key.startsWith('sb_publishable_')) return true;
    final segments = key.split('.');
    if (segments.length != 3) return false;
    try {
      // Legacy Supabase JWT keys encode the role in their payload.
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      return payload is Map && payload['role'] == 'anon';
    } on FormatException {
      return false;
    }
  }
}

class SharedAccount {
  const SharedAccount(this.client, this.config);

  final SupabaseClient client;
  final SharedAccountConfig config;
  User? get user => client.auth.currentUser;
  Stream<AuthState> get changes => client.auth.onAuthStateChange;

  static Future<SharedAccount> open(SharedAccountConfig config) async {
    final supabase = await Supabase.initialize(
      url: config.api.toString(),
      publishableKey: config.publishableKey,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        localStorage: Platform.isIOS
            ? _KeychainSession(config.api.origin)
            : const EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
    );
    return SharedAccount(supabase.client, config);
  }

  Future<void> signIn(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);

  Future<bool> signUp(String name, String email, String password) async {
    String? timezone;
    try {
      timezone = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      // The web database supplies its default if the OS clock is unavailable.
    }
    final response = await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: (config.confirmationOrigin ?? config.web)
          .resolve('/auth/confirm')
          .toString(),
      data: {'name': name, 'timezone': ?timezone},
    );
    return response.session != null;
  }

  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);
}

class _KeychainSession extends LocalStorage {
  const _KeychainSession(this.account);

  static const _channel = MethodChannel('app.paperdrawer.mobile/account');
  final String account;

  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() =>
      _channel.invokeMethod<String>('read', {'account': account});
  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;
  @override
  Future<void> persistSession(String value) => _channel.invokeMethod<void>(
    'write',
    {'account': account, 'value': value},
  );
  @override
  Future<void> removePersistedSession() =>
      _channel.invokeMethod<void>('remove', {'account': account});
}
