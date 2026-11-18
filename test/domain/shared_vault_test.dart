import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:paperdrawer/domain/models/shared_vault.dart';

void main() {
  test('maps web bill dates, USD cents, bill parts and a private original', () {
    final bill = SharedItem.bill({
      'id': 'bill',
      'created_at': '2026-01-31T12:00:00Z',
      'name': 'Washing machine',
      'purchased_on': '2026-01-31',
      'return_days': 14,
      'warranty_months': 1,
      'price': 199.99,
      'bill_parts': [
        {'name': 'Motor', 'years': 10},
      ],
      'attachments': [
        {
          'file_name': 'Invoice.pdf',
          'storage_path': 'owner/invoice.pdf',
          'mime_type': 'application/pdf',
        },
      ],
    });

    expect(bill.item.draft.currency, 'USD');
    expect(bill.item.draft.amountMinor, 19999);
    expect(bill.item.draft.returnUntil, DateTime.utc(2026, 2, 14));
    expect(bill.item.draft.coverUntil, DateTime.utc(2026, 2, 28));
    expect(bill.details, contains(('Motor', '10 years')));
    expect(bill.originals.single.path, 'owner/invoice.pdf');
  });

  test(
    'maps web policy amounts and claim state without inferring it from a date',
    () {
      final policy = SharedItem.document({
        'id': 'policy',
        'type': 'policy',
        'name': 'Home insurance',
        'created_at': '2026-11-01T12:00:00Z',
        'end_on': '2027-11-01',
        'sum_insured': '10000000000.01',
      });
      final claim = SharedClaim.fromRow({
        'id': 'claim',
        'document_id': 'policy',
        'title': 'Leak',
        'opened_on': '2026-11-18',
        'state': 'docs_asked',
        'claim_events': [
          {
            'title': 'Called support',
            'occurred_on': '2026-11-18',
            'created_at': '2026-11-18T10:30:00Z',
          },
          {
            'title': 'Sent requested document',
            'occurred_on': '2026-11-19',
            'created_at': '2026-11-19T10:30:00Z',
          },
        ],
      });

      expect(policy.item.kind, ItemKind.policy);
      expect(policy.details, contains(('Sum insured', r'$10,000,000,000.01')));
      expect(claim.itemId, 'policy');
      expect(claim.statusLabel, 'Documents requested');
      expect(claim.needsAction, isTrue);
      expect(claim.events.first.title, 'Sent requested document');
    },
  );
}
