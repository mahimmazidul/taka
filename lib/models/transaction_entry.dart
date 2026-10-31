/// Whether a [TransactionEntry] takes money out or brings money in.
enum EntryType {
  expense,
  income;

  static EntryType fromDb(Object? value) =>
      value == 'income' ? EntryType.income : EntryType.expense;

  String get dbValue => name;
}

/// A single money movement.
///
/// [amountMinor] is stored as an **integer number of paisa** (1 BDT = 100 paisa)
/// so repeated additions never drift the way floating point would. Convert only
/// when formatting, via `formatMoney`.
class TransactionEntry {
  const TransactionEntry({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.categoryId,
    required this.note,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final EntryType type;
  final int amountMinor;
  final String categoryId;
  final String note;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isExpense => type == EntryType.expense;

  TransactionEntry copyWith({
    EntryType? type,
    int? amountMinor,
    String? categoryId,
    String? note,
    DateTime? occurredAt,
    DateTime? updatedAt,
  }) {
    return TransactionEntry(
      id: id,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TransactionEntry.fromMap(Map<String, Object?> map) {
    return TransactionEntry(
      id: map['id']! as String,
      type: EntryType.fromDb(map['type']),
      amountMinor: map['amount_minor']! as int,
      categoryId: map['category_id']! as String,
      note: (map['note'] as String?) ?? '',
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        map['occurred_at']! as int,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'type': type.dbValue,
      'amount_minor': amountMinor,
      'category_id': categoryId,
      'note': note,
      'occurred_at': occurredAt.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}
