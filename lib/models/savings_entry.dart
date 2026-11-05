/// Which way money moved in the savings pot.
enum SavingsDirection {
  /// Taken out of the pocket and set aside.
  aside,

  /// Taken back out of the pot.
  back;

  static SavingsDirection fromDb(Object? value) =>
      value == 'back' ? SavingsDirection.back : SavingsDirection.aside;

  String get dbValue => name;

  String get label =>
      this == SavingsDirection.aside ? 'Set aside' : 'Took back';
}

/// One movement in or out of the savings pot.
///
/// Deliberately **not** a [TransactionEntry]: saving is not spending. The pot
/// reduces the money on hand exactly like an open udhar does, and never appears
/// in In/Out, in budgets or in Patterns.
class SavingsEntry {
  const SavingsEntry({
    required this.id,
    required this.direction,
    required this.amountMinor,
    required this.note,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final SavingsDirection direction;
  final int amountMinor;
  final String note;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// +1 for money going in, −1 for money coming back out.
  int get sign => direction == SavingsDirection.aside ? 1 : -1;

  /// This movement's effect on the pot's balance.
  int get deltaMinor => sign * amountMinor;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'direction': direction.dbValue,
      'amount_minor': amountMinor,
      'note': note,
      'occurred_at': occurredAt.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory SavingsEntry.fromMap(Map<String, Object?> map) {
    return SavingsEntry(
      id: map['id']! as String,
      direction: SavingsDirection.fromDb(map['direction']),
      amountMinor: map['amount_minor']! as int,
      note: (map['note'] as String?) ?? '',
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        map['occurred_at']! as int,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
    );
  }
}
