import 'vault_record.dart';

abstract interface class VaultRepository {
  Future<List<VaultRecord>> readAll();

  Future<void> save(VaultDraft draft, {String? id, VaultAttachment? import});

  Future<void> setArchived(String id, bool archived);

  Future<VaultAppearance> readTheme();

  Future<void> setTheme(VaultAppearance theme);
}
