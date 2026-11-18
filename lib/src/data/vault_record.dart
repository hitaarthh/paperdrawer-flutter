import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum VaultAppearance { system, light, dark }

enum RecordKind {
  receipt('Receipt', 'Receipts', 'Store or seller', 'Warranty ends'),
  policy('Policy', 'Policies', 'Insurer', 'Renews'),
  document('Document', 'Documents', 'Issuer', 'Due');

  const RecordKind(
    this.label,
    this.plural,
    this.sourceLabel,
    this.deadlineLabel,
  );

  final String label;
  final String plural;
  final String sourceLabel;
  final String deadlineLabel;
}

@immutable
class VaultDraft {
  const VaultDraft({
    required this.kind,
    required this.title,
    this.source = '',
    this.notes = '',
    this.amountCents,
    this.recordedOn,
    this.deadline,
  });

  final RecordKind kind;
  final String title;
  final String source;
  final String notes;
  final int? amountCents;
  final DateTime? recordedOn;
  final DateTime? deadline;
}

@immutable
class VaultAttachment {
  const VaultAttachment({required this.path, required this.name});

  final String path;
  final String name;
}

@immutable
class VaultRecord {
  const VaultRecord({
    required this.id,
    required this.draft,
    required this.createdAt,
    this.attachment,
    this.archivedAt,
  });

  final String id;
  final VaultDraft draft;
  final DateTime createdAt;
  final VaultAttachment? attachment;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
}

DateTime civilDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

String displayDate(DateTime date) => DateFormat.yMMMd().format(date);

String displayAmount(int cents) =>
    NumberFormat.simpleCurrency(name: 'USD').format(cents / 100);

int? parseAmountCents(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(trimmed)) {
    throw const FormatException('Enter a price like 49.99.');
  }
  final parts = trimmed.split('.');
  return int.parse(parts.first) * 100 +
      (parts.length == 2 ? int.parse(parts.last.padRight(2, '0')) : 0);
}
