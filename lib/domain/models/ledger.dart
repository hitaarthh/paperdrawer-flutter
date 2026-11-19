import '../formats.dart';
import 'item.dart';

enum LedgerKind {
  call('Call'),
  email('Email'),
  visit('Visit'),
  note('Note'),
  refund('Refund');

  const LedgerKind(this.label);
  final String label;
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.date,
    required this.kind,
    required this.text,
    this.details = '',
    this.reference = '',
  });

  final String id;
  final DateTime date;
  final LedgerKind kind;
  final String text;
  final String details;
  final String reference;
}

class LedgerDraft {
  LedgerDraft({
    this.id,
    required this.kind,
    required this.date,
    required String text,
    required String reference,
    this.photo,
    this.followUp,
  }) : text = text.trim(),
       reference = reference.trim();

  final String? id;
  final LedgerKind kind;
  final DateTime date;
  final String text;
  final String reference;
  final PendingFile? photo;
  final DateTime? followUp;

  void validate(DateTime now) {
    if (text.isEmpty) {
      throw const FormatException('Write a line about what happened.');
    }
    if (text.runes.length > 2000) {
      throw const FormatException('Keep the entry to 2,000 characters or fewer.');
    }
    if (reference.runes.length > 100) {
      throw const FormatException('Keep the reference to 100 characters or fewer.');
    }
    if (civil(date).isAfter(civil(now))) {
      throw const FormatException('Choose today or an earlier date for the entry.');
    }
    validateFollowUp(followUp, now);
  }
}

void validateFollowUp(DateTime? followUp, DateTime now) {
  if (followUp != null && !followUp.isAfter(now)) {
    throw const FormatException('Choose a follow-up time in the future.');
  }
}
