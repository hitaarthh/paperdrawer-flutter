import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/shared_notification.dart';

enum DrawerChange { drawer, notifications }

class SharedInboxService {
  const SharedInboxService(this._client);

  final SupabaseClient _client;

  Stream<DrawerChange> changes(String owner) {
    RealtimeChannel? channel;
    late final StreamController<DrawerChange> stream;
    stream = StreamController<DrawerChange>(
      onListen: () {
        channel = _client
            .channel(
              'paperdrawer:$owner',
              opts: const RealtimeChannelConfig(private: true),
            )
            .onBroadcast(
              event: 'changed',
              callback: (message) => stream.add(
                (message['payload'] as Map?)?['resource'] == 'notifications'
                    ? DrawerChange.notifications
                    : DrawerChange.drawer,
              ),
            )
            .subscribe((status, _) {
              if (status == RealtimeSubscribeStatus.subscribed) {
                stream.add(DrawerChange.drawer);
              }
            });
      },
      onCancel: () async {
        if (channel case final current?) await _client.removeChannel(current);
      },
    );
    return stream.stream;
  }

  Future<List<SharedNotification>> fetch(String owner) async {
    const pageSize = 250;
    final notifications = <SharedNotification>[];
    for (var offset = 0; ; offset += pageSize) {
      final rows = await _client
          .from('notification_inbox')
          .select('id,item_id,item_name,label,deadline_on,read_at')
          .eq('user_id', owner)
          .order('deadline_on', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      notifications.addAll(rows.map(SharedNotification.fromRow));
      if (rows.length < pageSize) return List.unmodifiable(notifications);
    }
  }

  Future<void> markRead(String owner, String id) async {
    if (_client.auth.currentUser?.id != owner) {
      throw const FormatException('Sign in to open this reminder.');
    }
    await _client.rpc<void>(
      'mark_notification_read',
      params: {'p_notification_id': id},
    );
  }
}
