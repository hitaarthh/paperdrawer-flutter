import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SharedAccountConfig {
  const SharedAccountConfig(this.api, this.publishableKey, this.web);

  final Uri api;
  final String publishableKey;
  final Uri web;

  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _web = String.fromEnvironment(
    'PAPERDRAWER_WEB_URL',
    defaultValue: 'https://paperdrawer.app',
  );

  static bool get requested => _url.isNotEmpty || _key.isNotEmpty;

  factory SharedAccountConfig.fromEnvironment() {
    final api = Uri.tryParse(_url);
    final web = Uri.tryParse(_web);
    if (!_validOrigin(api) || !_validOrigin(web) || _key.isEmpty ||
        _key.startsWith('sb_secret_')) {
      throw const FormatException('Set the Supabase URL, publishable key and PaperDrawer web URL.');
    }
    return SharedAccountConfig(api!, _key, web!);
  }

  static bool _validOrigin(Uri? uri) => uri != null &&
      uri.host.isNotEmpty && uri.userInfo.isEmpty &&
      (uri.scheme == 'https' ||
          (!kReleaseMode && uri.scheme == 'http' &&
              const {'localhost', '127.0.0.1', '::1'}.contains(uri.host)));
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
      emailRedirectTo: config.web.resolve('/auth/confirm').toString(),
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
  Future<void> persistSession(String value) =>
      _channel.invokeMethod<void>('write', {'account': account, 'value': value});
  @override
  Future<void> removePersistedSession() =>
      _channel.invokeMethod<void>('remove', {'account': account});
}
