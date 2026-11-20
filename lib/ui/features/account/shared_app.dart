import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app.dart';
import '../../../data/services/account_settings_sync.dart';
import '../../../data/services/drawer_actions.dart';
import '../../../data/services/drawer_storage.dart';
import '../../../data/services/reminder_scheduler.dart';
import '../../../data/services/shared_account.dart';
import '../../../drawer_runtime.dart';
import '../../../routing/paper_page.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/button.dart';
import '../intro/intro_flow.dart';
import 'account_screen.dart';
import 'drawer_account_actions.dart';

typedef _ActiveDrawer = ({
  DrawerRuntime runtime,
  DrawerAccountActions account,
  String? launchLocation,
});

/// Authentication chooses which local drawer to mount. Each transition tears
/// down the previous router and its providers before opening another drawer.
class AccountDrawerApp extends StatefulWidget {
  const AccountDrawerApp({
    required this.account,
    required this.storage,
    this.settingsRemote = SupabaseAccountSettings.new,
    super.key,
  });

  final SharedAccount account;
  final DrawerStorage storage;
  final AccountSettingsRemote Function(SupabaseClient, String) settingsRemote;

  @override
  State<AccountDrawerApp> createState() => _AccountDrawerAppState();
}

class _AccountDrawerAppState extends State<AccountDrawerApp> {
  late final StreamSubscription<AuthState> _changes;
  late Future<_ActiveDrawer?> _opening;
  _ActiveDrawer? _active;
  String? _ownerId;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final user = widget.account.user;
    _ownerId = user?.id;
    _opening = _open(user, ++_generation, useLaunchLocation: true);
    _changes = widget.account.changes.listen(
      (change) {
        final user = widget.account.user;
        if (_ownerId != user?.id) {
          _switch(user);
        } else if (change.event == AuthChangeEvent.tokenRefreshed) {
          unawaited(_active?.runtime.deps.settingsSync?.sync());
        }
      },
      onError: (Object _, StackTrace _) {
        // A refresh timeout does not change which drawer is open.
      },
    );
  }

  void _switch(User? user, {bool importLegacy = false}) {
    if (widget.account.user?.id != user?.id) return;
    final previous = _opening;
    _active?.runtime.stopSync();
    setState(() {
      _ownerId = user?.id;
      _opening = _open(
        user,
        ++_generation,
        previous: previous,
        importLegacy: importLegacy,
      );
    });
  }

  Future<_ActiveDrawer?> _open(
    User? user,
    int generation, {
    Future<_ActiveDrawer?>? previous,
    bool useLaunchLocation = false,
    bool importLegacy = false,
  }) async {
    if (previous != null) {
      final outgoing = await previous.then(
        (drawer) => drawer,
        onError: (Object _, StackTrace _) => null,
      );
      if (outgoing != null) {
        _active = null;
        await WidgetsBinding.instance.endOfFrame;
        await outgoing.runtime.close();
      }
    }
    if (!mounted || generation != _generation) return null;
    if (user == null) {
      if (useLaunchLocation) {
        try {
          await FlutterLocalNotificationsGateway().clear();
        } catch (_) {
          // The signed-out screen never follows reminder links.
        }
      }
      return null;
    }

    final owner = DrawerOwner(widget.account.config.api, user.id);
    final storage = widget.storage;
    final drawer = await storage.open(owner: owner);
    DrawerRuntime? runtime;
    try {
      if (!mounted || generation != _generation) {
        await drawer.close();
        return null;
      }
      if (importLegacy) await storage.importLegacy(owner, drawer);
      final legacyAvailable = await storage
          .canImportLegacy(owner, drawer)
          .onError((_, _) => false);
      if (!mounted || generation != _generation) {
        await drawer.close();
        return null;
      }
      runtime = DrawerRuntime(
        drawer,
        owner: owner,
        remote: widget.settingsRemote(widget.account.client, user.id),
      );
      final launchLocation = useLaunchLocation
          ? await runtime.launchLocation()
          : null;
      if (!mounted || generation != _generation) {
        await runtime.close();
        return null;
      }
      final name = user.userMetadata?['name'];
      return _active = (
        runtime: runtime,
        account: DrawerAccountActions(
          name: name is String && name.trim().isNotEmpty
              ? name.trim()
              : user.email?.split('@').first ?? 'Your account',
          email: user.email,
          signOut: () async {
            await widget.account.signOut();
            if (mounted && _ownerId == user.id && widget.account.user == null) {
              _switch(null);
            }
          },
          importLegacy: legacyAvailable
              ? () => _switch(user, importLegacy: true)
              : null,
        ),
        launchLocation: launchLocation,
      );
    } catch (_) {
      if (runtime != null) {
        await runtime.close();
      } else {
        await drawer.close();
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_changes.cancel());
    _active?.runtime.stopSync();
    unawaited(
      _opening.then(
        (drawer) => drawer?.runtime.close(),
        onError: (Object _, StackTrace _) {},
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ActiveDrawer?>(
    future: _opening,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _DrawerStatus();
      }
      if (snapshot.hasError) {
        final error = snapshot.error;
        return _DrawerStatus(
          message: error is FormatException
              ? error.message
              : 'Couldn’t open your drawer. Try again.',
          retry: () => _switch(widget.account.user),
        );
      }
      final opened = snapshot.data;
      return opened == null
          ? _AccountEntry(account: widget.account)
          : PaperDrawerApp(
              key: ObjectKey(opened.runtime),
              deps: opened.runtime.deps,
              initialLocation: opened.launchLocation,
              account: opened.account,
            );
    },
  );
}

class _AccountEntry extends StatefulWidget {
  const _AccountEntry({required this.account});
  final SharedAccount account;

  @override
  State<_AccountEntry> createState() => _AccountEntryState();
}

class _AccountEntryState extends State<_AccountEntry> {
  late final _router = GoRouter(
    initialLocation: '/intro',
    routes: [
      GoRoute(
        path: '/intro',
        builder: (context, state) => IntroFlow(
          onStart: () => context.go('/account?mode=create'),
          onSignIn: () => context.go('/account'),
        ),
      ),
      GoRoute(
        path: '/account',
        pageBuilder: (context, state) => PdPage<void>(
          key: state.pageKey,
          child: AccountScreen(
            account: widget.account,
            startCreating: state.uri.queryParameters['mode'] == 'create',
            openWeb: (path) => const DrawerActions().openLink(
              widget.account.config.web.resolve(path),
            ),
          ),
        ),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Paper Drawer',
    debugShowCheckedModeBanner: false,
    routerConfig: _router,
    theme: pdTheme(),
  );
}

class _DrawerStatus extends StatelessWidget {
  const _DrawerStatus({this.message, this.retry});

  final String? message;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: pdTheme(),
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Pd.margin),
          child: message == null
              ? const CircularProgressIndicator(
                  semanticsLabel: 'Opening drawer',
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: Pd.s4,
                  children: [
                    Text(message!, textAlign: TextAlign.center),
                    PdButton.text(label: 'Try again', onPressed: retry),
                  ],
                ),
        ),
      ),
    ),
  );
}
