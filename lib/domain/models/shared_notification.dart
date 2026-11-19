import '../formats.dart';

class SharedNotification {
  const SharedNotification({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.label,
    required this.deadline,
    required this.isRead,
  });

  factory SharedNotification.fromRow(Map<String, dynamic> row) =>
      SharedNotification(
        id: row['id'] as String,
        itemId: row['item_id'] as String,
        itemName: row['item_name'] as String,
        label: row['label'] as String,
        deadline: parseIsoDate(row['deadline_on'])!,
        isRead: row['read_at'] != null,
      );

  final String id;
  final String itemId;
  final String itemName;
  final String label;
  final DateTime deadline;
  final bool isRead;
}
