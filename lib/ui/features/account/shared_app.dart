import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/services/capture_service.dart';
import '../../../data/services/shared_account.dart';
import '../../../data/services/text_recognizer.dart';
import '../../../data/services/today.dart';
import '../../../routing/shared_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/button.dart';
import '../intro/app_opening.dart';
import 'shared_session.dart';

class SharedBootstrap extends StatefulWidget {
  const SharedBootstrap({super.key});

  @override
  State<SharedBootstrap> createState() => _SharedBootstrapState();
}

class _SharedBootstrapState extends State<SharedBootstrap> {
  late Future<SharedAccount> _opening = _open();

  Future<SharedAccount> _open() async =>
      SharedAccount.open(SharedAccountConfig.fromEnvironment());

  @override
  Widget build(BuildContext context) => AppOpening(
    opening: _opening,
    appBuilder: _SharedApp.new,
    errorBuilder: (error) => MaterialApp(
      theme: pdTheme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Pd.margin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: Pd.s4,
              children: [
                Text(
                  error is FormatException
                      ? error.message
                      : 'Paper Drawer couldn’t open the account service.',
                  textAlign: TextAlign.center,
                ),
                PdButton.text(
                  label: 'Try again',
                  onPressed: () => setState(() => _opening = _open()),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SharedApp extends StatefulWidget {
  const _SharedApp(this.account);
  final SharedAccount account;

  @override
  State<_SharedApp> createState() => _SharedAppState();
}

class _SharedAppState extends State<_SharedApp> with WidgetsBindingObserver {
  late final _session = SharedSession(widget.account);
  late final _router = buildSharedRouter(_session);
  late final StreamSubscription<String> _claimReminderTaps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _claimReminderTaps = _session.followUps.taps.listen(_openClaimReminder);
    unawaited(_openLaunchReminder());
  }

  Future<void> _openLaunchReminder() async {
    final location = await _session.followUps.launchLocation();
    if (!mounted || location == null) return;
    _openClaimReminder(location);
  }

  void _openClaimReminder(String location) {
    if (_session.signedIn && location.startsWith('/claims/')) {
      _router.go(location);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _session.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_claimReminderTaps.cancel());
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: _session),
      Provider<CaptureService>.value(value: _session.capture),
      Provider<TextRecognizer>(create: (_) => PlatformTextRecognizer()),
      ChangeNotifierProvider<Today>.value(value: _session.today),
    ],
    child: MaterialApp.router(
      title: 'Paper Drawer',
      theme: pdTheme(),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: 2),
          ),
          child: child!,
        );
      },
    ),
  );
}
