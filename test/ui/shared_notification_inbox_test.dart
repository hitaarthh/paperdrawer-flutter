import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/data/repositories/shared_inbox_repository.dart';
import 'package:paperdrawer/data/services/shared_inbox_service.dart';
import 'package:paperdrawer/domain/models/shared_notification.dart';
import 'package:paperdrawer/routing/router.dart';
import 'package:paperdrawer/ui/core/theme/app_theme.dart';
import 'package:paperdrawer/ui/features/reminders/reminder_inbox.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('opening a reminder marks it read and opens the item at 130% text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final service = _InboxService();
    addTearDown(service.client.dispose);
    final inbox = SharedInboxRepository(service)..setOwner('alice');
    addTearDown(inbox.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: DrawerNotificationButton()),
        ),
        GoRoute(
          path: Routes.notifications,
          builder: (_, _) => const ReminderInbox(shared: true),
        ),
        GoRoute(
          path: '/vault/item/:id',
          builder: (_, state) => Scaffold(body: Text('Item ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: inbox,
        child: MaterialApp.router(theme: pdTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(inbox.unread, 1);
    await tester.tap(find.byKey(const ValueKey('drawer-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('A receipt for the living room television'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notification-deadline')));
    await tester.pumpAndSettle();
    expect(service.marked, ['alice/deadline']);
    expect(inbox.unread, 0);
    expect(find.text('Item television'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('a fetch from the previous account cannot populate the next inbox', () async {
    final service = _InboxService();
    addTearDown(service.client.dispose);
    final stale = Completer<List<SharedNotification>>();
    service.aliceResponse = stale.future;
    final inbox = SharedInboxRepository(service)..setOwner('alice');
    addTearDown(inbox.dispose);
    final aliceLoad = inbox.refresh();

    inbox.setOwner('bob');
    await inbox.refresh();
    stale.complete([_InboxService.reminder(false)]);
    await aliceLoad;

    expect(inbox.loaded, isTrue);
    expect(inbox.items, isEmpty);
  });
}

class _InboxService extends SharedInboxService {
  _InboxService() : this._(SupabaseClient('https://example.invalid', 'unused'));
  _InboxService._(this.client) : super(client);

  final SupabaseClient client;
  final marked = <String>[];
  Future<List<SharedNotification>>? aliceResponse;

  static SharedNotification reminder(bool read) => SharedNotification(
    id: 'deadline',
    itemId: 'television',
    itemName: 'A receipt for the living room television',
    label: 'Return window',
    deadline: DateTime.utc(2026, 11, 20),
    isRead: read,
  );

  @override
  Future<List<SharedNotification>> fetch(String owner) async {
    if (owner != 'alice') return [];
    if (aliceResponse case final response?) return response;
    return [reminder(marked.isNotEmpty)];
  }

  @override
  Future<void> markRead(String owner, String id) async => marked.add('$owner/$id');
}
