import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/ui/core/widgets/icons.dart';
import 'package:paperdrawer/ui/core/widgets/paper.dart';
import 'package:paperdrawer/ui/features/intro/app_opening.dart';

const _artwork = ValueKey('opening-artwork');
const _wordmark = 'PaperDrawer';
const _ticketCopy = 'Never lose a claim to a missing bill.';
const _tagline = 'KEEP IT · REMEMBER IT · CLAIM IT';

void main() {
  testWidgets('plays the reveal in order even when startup is already ready', (
    tester,
  ) async {
    _useIPhone16(tester);
    await _mount(tester, Future.value('Vault'));
    final mark = find.byType(PaperDrawerMark);
    final start = tester.getCenter(mark);
    expect(start.dy, closeTo(426, 1));
    expect(_opacity(tester, _wordmark), 0);
    expect(_ticketFraction(tester), 0);
    expect(_opacity(tester, 'FILED'), 0);
    expect(_opacity(tester, _tagline), 0);
    expect(find.text('Vault'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getCenter(mark).dy, lessThan(start.dy));
    expect(_opacity(tester, _wordmark), greaterThan(0));
    expect(_ticketFraction(tester), 0);

    await tester.pump(const Duration(milliseconds: 250));
    expect(_ticketFraction(tester), allOf(greaterThan(0), lessThan(1)));
    expect(_opacity(tester, 'FILED'), 0);

    await tester.pump(const Duration(milliseconds: 350));
    expect(_ticketFraction(tester), 1);
    expect(_opacity(tester, 'FILED'), greaterThan(0));
    expect(_opacity(tester, _tagline), 0);

    await tester.pump(const Duration(milliseconds: 250));
    expect(_opacity(tester, _tagline), 1);
    expect(find.text('Vault'), findsOneWidget);
    expect(find.byKey(_artwork), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(_artwork), findsNothing);
    expect(find.text('Vault'), findsOneWidget);
  });

  testWidgets('holds the final frame until slow startup finishes', (
    tester,
  ) async {
    _useIPhone16(tester);
    final startup = Completer<String>();
    await _mount(tester, startup.future);
    await tester.pumpAndSettle();
    expect(_ticketFraction(tester), 1);
    expect(_opacity(tester, _tagline), 1);
    expect(find.text('Vault'), findsNothing);

    await tester.pump(const Duration(seconds: 6));
    expect(_opacity(tester, _wordmark), 1);
    expect(_ticketFraction(tester), 1);

    startup.complete('Vault');
    await tester.pumpAndSettle();
    expect(find.byKey(_artwork), findsNothing);
    expect(find.text('Vault'), findsOneWidget);
  });

  testWidgets('reduced motion uses a static frame and opens without waiting', (
    tester,
  ) async {
    _useIPhone16(tester);
    final startup = Completer<String>();
    await _mount(tester, startup.future, reduceMotion: true);
    expect(_opacity(tester, _wordmark), 1);
    expect(_ticketFraction(tester), 1);

    startup.complete('Vault');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_artwork), findsNothing);
    expect(find.text('Vault'), findsOneWidget);
  });

  testWidgets('shows startup errors promptly and retries without replaying', (
    tester,
  ) async {
    _useIPhone16(tester);
    final failedStartup = Completer<String>();
    await _mount(tester, failedStartup.future);
    failedStartup.completeError(StateError('startup failed'));
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(_artwork), findsNothing);

    final retry = Completer<String>();
    await _mount(tester, retry.future);
    expect(find.text('Try again'), findsNothing);
    expect(_opacity(tester, _tagline), 1);

    retry.complete('Vault');
    await tester.pumpAndSettle();
    expect(find.text('Vault'), findsOneWidget);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('opening artwork fits at ${scale}× text size', (tester) async {
      _useIPhone16(tester);
      final startup = Completer<String>();
      await _mount(
        tester,
        startup.future,
        reduceMotion: true,
        textScale: scale,
      );
      final ticket = tester.getRect(find.byType(NotchedTicketPaper));
      final title = tester.getRect(find.text(_ticketCopy));
      expect(ticket.contains(title.topLeft), isTrue);
      expect(ticket.contains(title.bottomRight), isTrue);
      expect(
        tester.getBottomLeft(find.text(_wordmark)).dy,
        lessThan(ticket.top),
      );
      expect(
        ticket.bottom,
        lessThan(tester.getTopLeft(find.text(_tagline)).dy),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

void _useIPhone16(WidgetTester tester) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
  addTearDown(tester.view.reset);
}

Future<void> _mount(
  WidgetTester tester,
  Future<String> opening, {
  bool reduceMotion = false,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: AppOpening(
          opening: opening,
          appBuilder: Text.new,
          errorBuilder: (_) => const Text('Try again'),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _opacity(WidgetTester tester, String text) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first,
    )
    .opacity;

double _ticketFraction(WidgetTester tester) {
  final ticket = find.byType(NotchedTicketPaper);
  final clip = tester.widget<ClipRect>(
    find.ancestor(of: ticket, matching: find.byType(ClipRect)).first,
  );
  final size = tester.getSize(ticket);
  return clip.clipper!.getClip(size).height / size.height;
}
