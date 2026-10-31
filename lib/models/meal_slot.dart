/// Which meal of the day an expense belongs to.
///
/// Optional on every entry: a bag of shampoo or a bus fare is not a meal, and
/// forcing a choice would add a tap to the most common case. The add-entry
/// screen guesses from the clock and lets you tap to change it.
enum MealSlot {
  breakfast,
  lunch,
  dinner;

  String get dbValue => name;

  String get label => switch (this) {
    MealSlot.breakfast => 'Breakfast',
    MealSlot.lunch => 'Lunch',
    MealSlot.dinner => 'Dinner',
  };

  String get labelBn => switch (this) {
    MealSlot.breakfast => 'সকাল',
    MealSlot.lunch => 'দুপুর',
    MealSlot.dinner => 'রাত',
  };

  static MealSlot? fromDb(Object? value) {
    if (value is! String) return null;
    for (final MealSlot slot in MealSlot.values) {
      if (slot.name == value) return slot;
    }
    return null;
  }

  /// 5–10 → breakfast, 11–16 → lunch, 17–23 → dinner. Outside those hours we
  /// return `null` rather than guess wrong at 2 am.
  static MealSlot? guess(DateTime at) {
    final int hour = at.hour;
    if (hour >= 5 && hour < 11) return MealSlot.breakfast;
    if (hour >= 11 && hour < 17) return MealSlot.lunch;
    if (hour >= 17 && hour < 24) return MealSlot.dinner;
    return null;
  }
}
