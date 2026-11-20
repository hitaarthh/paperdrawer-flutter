import 'package:flutter/foundation.dart';

@immutable
class DrawerAccountActions {
  const DrawerAccountActions({
    required this.name,
    required this.email,
    required this.signOut,
    this.importLegacy,
  });

  final String name;
  final String? email;
  final Future<void> Function() signOut;
  final VoidCallback? importLegacy;
}
