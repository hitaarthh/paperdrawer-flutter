import 'package:flutter/foundation.dart';

import '../account/account_scope.dart';
import 'notification_kind.dart';
import 'reminder_item.dart';

/// What a notification carries, so a tap or an action can find its account,
/// item and deadline again.
///
/// Version 2 (this rebuild) is `pd2;` followed by `name=value` fields joined
/// by `;`, each value percent-encoded:
///
/// ```text
/// pd2;scope=guest;kind=returnWindow;item=<id>;date=2026-11-27;route=%2Fvault%2Fitem%2F<id>
/// ```
///
/// - `scope`: `guest`, or `<projectKey>/<userId>` (the same string as
///   design-v1's `DrawerOwner.key`).
/// - `kind`: `NotificationKind.name`; absent for a one-off item reminder.
/// - `item`, `date`: the item ID and the deadline's end date, when the
///   notification is about one.
/// - `route`: where a tap goes (`/vault/item/<id>`, `/home`, …).
///
/// Unknown fields are ignored, so later versions can add fields. design-v1
/// payloads (version 1) still parse: a bare route (`/vault/item/<id>`,
/// guest) or `<scope>|<route>` (signed in).
@immutable
final class NotificationPayload {
  const NotificationPayload({
    required this.scope,
    required this.route,
    this.kind,
    this.itemId,
    this.deadline,
    this.version = currentVersion,
  });

  static const currentVersion = 2;
  static const _prefix = 'pd2;';

  /// Whose drawer this notification belongs to.
  final AccountScope scope;
  final String route;
  final NotificationKind? kind;
  final String? itemId;

  /// The deadline's end date (civil), for deadline notifications.
  final DateTime? deadline;

  /// 1 for design-v1 payloads, 2 for this format.
  final int version;

  String encode() {
    final fields = <String, String>{
      'scope': scopeKey(scope),
      if (kind case final kind?) 'kind': kind.name,
      if (itemId case final itemId?) 'item': itemId,
      if (deadline case final deadline?) 'date': isoDay(deadline),
      'route': route,
    };
    return _prefix +
        fields.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join(';');
  }

  /// Parses a stored payload; `null` when it is not one PaperDrawer wrote
  /// (or names an account scope that does not validate).
  static NotificationPayload? parse(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    if (payload.startsWith(_prefix)) return _parseV2(payload);
    return _parseV1(payload);
  }

  /// The route to open when [active] is the open drawer, or `null` when the
  /// notification belongs to another account (it must not open this one).
  String? routeFor(AccountScope active) => scope == active ? route : null;

  /// `guest` or `<projectKey>/<userId>`.
  static String scopeKey(AccountScope scope) => switch (scope) {
    GuestScope() => 'guest',
    UserScope(:final projectKey, :final id) => '$projectKey/$id',
  };

  /// Reads [scopeKey]'s form back; `null` when it does not validate.
  static AccountScope? parseScopeKey(String key) {
    if (key == 'guest') return const GuestScope();
    final slash = key.lastIndexOf('/');
    if (slash <= 0) return null;
    return UserScope.parse(
      projectKey: key.substring(0, slash),
      userId: key.substring(slash + 1),
    ).valueOrNull;
  }

  static NotificationPayload? _parseV2(String payload) {
    final fields = <String, String>{};
    for (final part in payload.substring(_prefix.length).split(';')) {
      final equals = part.indexOf('=');
      if (equals <= 0) return null;
      final value = _decode(part.substring(equals + 1));
      if (value == null) return null;
      fields[part.substring(0, equals)] = value;
    }
    final scope = parseScopeKey(fields['scope'] ?? '');
    final route = fields['route'];
    if (scope == null || route == null || !route.startsWith('/')) return null;
    final kindName = fields['kind'];
    final kind = kindName == null ? null : _kindNamed(kindName);
    if (kindName != null && kind == null) return null;
    final dateText = fields['date'];
    final date = dateText == null ? null : parseIsoDay(dateText);
    if (dateText != null && date == null) return null;
    return NotificationPayload(
      scope: scope,
      route: route,
      kind: kind,
      itemId: fields['item'],
      deadline: date,
    );
  }

  /// Percent-decodes [value]; `null` when the encoding is broken.
  static String? _decode(String value) {
    try {
      return Uri.decodeComponent(value);
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
  }

  static NotificationPayload? _parseV1(String payload) {
    if (payload.startsWith('/')) {
      return NotificationPayload(
        scope: const GuestScope(),
        route: payload,
        itemId: _itemOf(payload),
        version: 1,
      );
    }
    final bar = payload.indexOf('|');
    if (bar <= 0) return null;
    final scope = parseScopeKey(payload.substring(0, bar));
    final route = payload.substring(bar + 1);
    if (scope == null || !route.startsWith('/')) return null;
    return NotificationPayload(
      scope: scope,
      route: route,
      itemId: _itemOf(route),
      version: 1,
    );
  }

  /// The item ID in an item route (`/vault/item/<id>`).
  static String? _itemOf(String route) {
    const itemRoute = '/vault/item/';
    if (!route.startsWith(itemRoute)) return null;
    final id = route.substring(itemRoute.length);
    return id.isEmpty || id.contains('/') ? null : id;
  }

  static NotificationKind? _kindNamed(String name) {
    for (final kind in NotificationKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPayload &&
      other.scope == scope &&
      other.route == route &&
      other.kind == kind &&
      other.itemId == itemId &&
      other.deadline == deadline &&
      other.version == version;

  @override
  int get hashCode =>
      Object.hash(scope, route, kind, itemId, deadline, version);

  @override
  String toString() => 'NotificationPayload(v$version, ${kind?.name}, $route)';
}

/// Routes notifications open.
abstract final class NotificationRoutes {
  static const home = '/home';
  static const yourData = '/settings/data';
  static const account = '/settings/account';
  static String item(String id) => '/vault/item/$id';
}
