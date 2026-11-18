import '../claim_message.dart';
import '../formats.dart';
import 'item.dart';
import 'shared_profile.dart';

class SharedOriginal {
  const SharedOriginal({
    required this.name,
    required this.path,
    required this.mime,
  });

  final String name;
  final String path;
  final String mime;

  factory SharedOriginal.fromRow(Map<String, dynamic> row) => SharedOriginal(
    name: row['file_name'] as String,
    path: row['storage_path'] as String,
    mime: row['mime_type'] as String,
  );
}

class SharedItem {
  const SharedItem(this.item, this.originals, this.details, {this.ref});

  final Item item;
  final List<SharedOriginal> originals;
  final List<(String, String)> details;
  final String? ref;

  String get webPath =>
      '/${item.kind == ItemKind.bill ? 'bills' : 'documents'}/${item.id}';
  String get editPath =>
      '/${item.kind == ItemKind.bill ? 'bills' : 'documents'}/new?edit=${Uri.encodeQueryComponent(ref ?? item.id)}';
  String get startClaimPath =>
      '/claims/new?item=${Uri.encodeQueryComponent(ref ?? item.id)}';

  factory SharedItem.bill(Map<String, dynamic> row) {
    final bought = parseIsoDate(row['purchased_on'])!;
    final returnDays = row['return_days'] as int;
    final warranty = row['warranty_months'] as int;
    return SharedItem(
      Item(
        id: row['id'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        draft: ItemDraft(
          kind: ItemKind.bill,
          name: row['name'] as String,
          source: _text(row['store']),
          reference: _text(row['invoice_no']),
          serialNumber: _text(row['serial_no']),
          notes: _text(row['notes']),
          startsOn: bought,
          returnUntil: returnDays == 0 ? null : addDays(bought, returnDays),
          coverUntil: warranty == 0 ? null : addMonths(bought, warranty),
          amountMinor: _minor(row['price']),
          currency: 'USD',
        ),
      ),
      _originals(row),
      [
        ..._facts(row, const {
          'category': 'Category',
          'store_address': 'Store address',
          'invoice_no': 'Invoice number',
          'serial_no': 'Serial number',
          'warranty_type': 'Warranty type',
          'receipt_item': 'On the receipt',
        }),
        if (_minor(row['tax']) case final tax?) ('Tax', money(tax, 'USD')),
        for (final part in _rows(row['bill_parts']))
          (_text(part['name']), monthsLabel((part['years'] as int) * 12)),
      ],
      ref: row['ref'] as String?,
    );
  }

  factory SharedItem.document(Map<String, dynamic> row) => SharedItem(
    Item(
      id: row['id'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      draft: ItemDraft(
        kind: switch (row['type']) {
          'policy' => ItemKind.policy,
          'vehicle' => ItemKind.vehicle,
          _ => ItemKind.agreement,
        },
        name: row['name'] as String,
        subtype: _text(row['subtype']),
        source: _text(row['issuer']),
        reference: _text(row['number']),
        notes: _text(row['notes']),
        startsOn: parseIsoDate(row['start_on']),
        coverUntil: parseIsoDate(row['end_on']),
        amountMinor: _minor(row['amount']),
        currency: 'USD',
      ),
    ),
    _originals(row),
    [
      ..._facts(row, const {
        'subtype': 'Type',
        'number': 'Document number',
        'plan_name': 'Plan',
        'covers': 'Covers',
        'helpline': 'Helpline',
        'tpa': 'Administrator',
      }),
      if (_minor(row['sum_insured']) case final insured?)
        ('Sum insured', money(insured, 'USD')),
    ],
    ref: row['ref'] as String?,
  );
}

class SharedClaim {
  SharedClaim.fromRow(Map<String, dynamic> row)
    : id = row['id'] as String,
      title = row['title'] as String,
      itemId = (row['bill_id'] ?? row['document_id']) as String?,
      state = _text(row['state']),
      type = _text(row['type']),
      opened = parseIsoDate(row['opened_on'])!,
      lastHeard = parseIsoDate(row['last_heard_on']),
      settled = parseIsoDate(row['settled_on']),
      step = row['step'] as int? ?? 0,
      draft = _claimDraft(row['draft']),
      nextStep = _claimNextStep(row['next_step']),
      problem = _text(row['description']),
      itemLabel = _text(row['item_label']),
      facts = _facts(row, const {
        'reference': 'Reference',
        'wants': 'Requested resolution',
      }),
      originals = _originals(row),
      events = _rows(row['claim_events']).map(SharedClaimEvent.fromRow).toList()
        ..sort((a, b) {
          final date = b.date.compareTo(a.date);
          return date != 0 ? date : b.createdAt.compareTo(a.createdAt);
        });

  final String id;
  final String title;
  final String? itemId;
  final String state;
  final String type;
  final DateTime opened;
  final DateTime? lastHeard;
  final DateTime? settled;
  final int step;
  final ClaimMessage? draft;
  final (String, String)? nextStep;
  final String problem;
  final String itemLabel;
  final List<(String, String)> facts;
  final List<SharedOriginal> originals;
  final List<SharedClaimEvent> events;

  String get statusLabel => switch (state) {
    'no_reply' => 'No reply',
    'docs_asked' => 'Documents requested',
    'settled' => 'Settled',
    _ => 'Waiting',
  };

  // Labels follow the web vault's claim stages, which can differ from the
  // on-device drawer's escalation guidance.
  List<String> get ladderTitles => switch (type) {
    'repair' => const ['Brand support', 'Customer relations', 'Consumer protection', 'Small claims court'],
    'refund' => const ['Seller support', 'Escalate with the seller', 'Card dispute', 'Small claims court'],
    'insurance' => const ['Insurer claims team', 'Internal appeal', 'State insurance department', 'External review'],
    _ => const ['Ask the company', 'Escalate inside', 'Regulator or agency', 'Formal complaint'],
  };

  bool get needsAction => state == 'no_reply' || state == 'docs_asked';
  int day(DateTime today) =>
      daysBetween(opened, settled ?? today).clamp(0, 1 << 30);
  String get webPath => '/claims/$id';
}

ClaimMessage? _claimDraft(Object? data) {
  if (data is! Map<String, dynamic> || data['body'] is! List) return null;
  final body = (data['body'] as List).whereType<String>().join('\n\n').trim();
  if (body.isEmpty) return null;
  return ClaimMessage(
    to: _text(data['to']),
    subject: _text(data['subject']),
    body: body,
  );
}

(String, String)? _claimNextStep(Object? data) {
  if (data is! Map<String, dynamic>) return null;
  final title = _text(data['title']);
  final text = _text(data['text']);
  return title.isEmpty || text.isEmpty ? null : (title, text);
}

class SharedClaimEvent {
  SharedClaimEvent.fromRow(Map<String, dynamic> row)
    : date = parseIsoDate(row['occurred_on'])!,
      createdAt = DateTime.parse(row['created_at'] as String),
      title = row['title'] as String,
      note = _text(row['note']);

  final DateTime date;
  final DateTime createdAt;
  final String title;
  final String note;
}

class SharedVault {
  const SharedVault({required this.items, required this.claims, this.profile});

  final List<SharedItem> items;
  final List<SharedClaim> claims;
  final SharedProfile? profile;

  bool get onBasePlan => profile?.onBasePlan ?? true;
}

String _text(Object? value) => value as String? ?? '';
int? _minor(Object? value) {
  if (value == null) return null;
  final parts = value.toString().split('.');
  final fraction = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  return int.parse(parts.first) * 100 + int.parse(fraction);
}

Iterable<Map<String, dynamic>> _rows(Object? value) =>
    (value as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

List<SharedOriginal> _originals(Map<String, dynamic> row) =>
    _rows(row['attachments']).map(SharedOriginal.fromRow).toList();

List<(String, String)> _facts(
  Map<String, dynamic> row,
  Map<String, String> labels,
) => [
  for (final entry in labels.entries)
    if (_text(row[entry.key]).isNotEmpty) (entry.value, _text(row[entry.key])),
];
