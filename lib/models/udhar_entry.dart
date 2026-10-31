/// Direction of an udhar (lend/borrow) record.
enum UdharType {
  /// I gave money to someone; they owe me.
  lent,

  /// I took money from someone; I owe them.
  borrowed;

  static UdharType fromDb(Object? value) =>
      value == 'borrowed' ? UdharType.borrowed : UdharType.lent;

  String get dbValue => name;

  String get label => this == UdharType.lent ? 'Lent' : 'Borrowed';
}

class UdharEntry {
  const UdharEntry({
    required this.id,
    required this.type,
    required this.person,
    required this.amountMinor,
    required this.note,
    required this.occurredAt,
    required this.returned,
    this.returnedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final UdharType type;
  final String person;
  final int amountMinor;
  final String note;
  final DateTime occurredAt;
  final bool returned;
  final DateTime? returnedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  UdharEntry copyWith({
    UdharType? type,
    String? person,
    int? amountMinor,
    String? note,
    DateTime? occurredAt,
    bool? returned,
    DateTime? returnedAt,
    bool clearReturnedAt = false,
    DateTime? updatedAt,
  }) {
    return UdharEntry(
      id: id,
      type: type ?? this.type,
      person: person ?? this.person,
      amountMinor: amountMinor ?? this.amountMinor,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      returned: returned ?? this.returned,
      returnedAt: clearReturnedAt ? null : (returnedAt ?? this.returnedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UdharEntry.fromMap(Map<String, Object?> map) {
    final int? returnedAtMs = map['returned_at'] as int?;
    return UdharEntry(
      id: map['id']! as String,
      type: UdharType.fromDb(map['type']),
      person: map['person']! as String,
      amountMinor: map['amount_minor']! as int,
      note: (map['note'] as String?) ?? '',
      occurredAt: DateTime.fromMillisecondsSinceEpoch(map['occurred_at']! as int),
      returned: (map['returned'] as int? ?? 0) == 1,
      returnedAt: returnedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(returnedAtMs),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'type': type.dbValue,
      'person': person,
      'amount_minor': amountMinor,
      'note': note,
      'occurred_at': occurredAt.millisecondsSinceEpoch,
      'returned': returned ? 1 : 0,
      'returned_at': returnedAt?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}

/// Outstanding (not yet returned) totals, used by the Home udhar strip.
class UdharTotals {
  const UdharTotals({required this.lentMinor, required this.borrowedMinor});

  const UdharTotals.empty() : lentMinor = 0, borrowedMinor = 0;

  /// Money other people still owe me.
  final int lentMinor;

  /// Money I still owe other people.
  final int borrowedMinor;

  int get netMinor => lentMinor - borrowedMinor;

  bool get isEmpty => lentMinor == 0 && borrowedMinor == 0;
}
