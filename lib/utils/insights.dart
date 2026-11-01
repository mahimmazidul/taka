import '../models/app_category.dart';
import '../models/meal_slot.dart';
import '../models/transaction_entry.dart';
import 'date_helpers.dart';
import 'period_stats.dart';

/// How often a meal went unlogged — the "did I skip breakfast again" question.
class MealGap {
  const MealGap({
    required this.slot,
    required this.missedDays,
    required this.days,
  });

  final MealSlot slot;

  /// Days in the window with no food entry tagged to this meal.
  final int missedDays;

  /// Days actually finished (today counts only once it is over for that meal).
  final int days;

  int get loggedDays => days - missedDays;

  double get missedShare => days == 0 ? 0 : missedDays / days;
}

/// One category's slice of a period.
class CategorySpend {
  const CategorySpend({
    required this.category,
    required this.amountMinor,
    required this.entries,
  });

  final AppCategory category;
  final int amountMinor;
  final int entries;
}

/// Meals missed per slot in a window.
///
/// Only *food* entries count: a face wash logged at 8 am is not breakfast and
/// must never make the app think you ate. A day is missed when nothing was
/// logged for that slot at all — which is a hint, not an accusation, so the UI
/// says "no breakfast logged", never "you skipped".
List<MealGap> missedMeals(
  List<TransactionEntry> entries,
  List<AppCategory> categories, {
  required DateTime from,
  required DateTime toExclusive,
  required DateTime now,
}) {
  final Set<String> foodIds = <String>{
    for (final AppCategory category in categories)
      if (category.isFood) category.id,
  };

  final Map<MealSlot, Set<DateTime>> logged = <MealSlot, Set<DateTime>>{
    for (final MealSlot slot in MealSlot.values) slot: <DateTime>{},
  };

  for (final TransactionEntry entry in entries) {
    if (!entry.isExpense) continue;
    if (!foodIds.contains(entry.categoryId)) continue;
    final MealSlot? slot = entry.meal;
    if (slot == null) continue;
    final DateTime day = startOfDay(entry.occurredAt);
    if (day.isBefore(from) || !day.isBefore(toExclusive)) continue;
    logged[slot]!.add(day);
  }

  final List<MealGap> gaps = <MealGap>[];
  for (final MealSlot slot in MealSlot.values) {
    int days = 0;
    for (
      DateTime day = startOfDay(from);
      day.isBefore(toExclusive) && day.isBefore(startOfNextDay(now));
      day = startOfNextDay(day)
    ) {
      // Today only counts for a meal whose hour has already passed, otherwise
      // the app accuses you of missing dinner at noon.
      if (isSameDay(day, now) && !_mealHasPassed(slot, now)) continue;
      days++;
    }
    final int missed = days - logged[slot]!.length.clamp(0, days);
    gaps.add(MealGap(slot: slot, missedDays: missed, days: days));
  }
  return gaps;
}

bool _mealHasPassed(MealSlot slot, DateTime now) {
  final int hour = now.hour;
  return switch (slot) {
    MealSlot.breakfast => hour >= 11,
    MealSlot.lunch => hour >= 17,
    MealSlot.dinner => hour >= 22,
  };
}

/// Where the money went, biggest first, groups rolled up into their items.
///
/// A group that carries its own entries (Dining out used to) is kept as its own
/// row, so nothing silently vanishes from the list.
List<CategorySpend> topSpending(
  List<TransactionEntry> entries,
  List<AppCategory> categories, {
  required DateTime from,
  required DateTime toExclusive,
}) {
  final Map<String, AppCategory> byId = <String, AppCategory>{
    for (final AppCategory category in categories) category.id: category,
  };
  final Map<String, int> amounts = <String, int>{};
  final Map<String, int> counts = <String, int>{};

  for (final TransactionEntry entry in entries) {
    if (!entry.isExpense) continue;
    if (entry.occurredAt.isBefore(from) ||
        !entry.occurredAt.isBefore(toExclusive)) {
      continue;
    }
    amounts[entry.categoryId] =
        (amounts[entry.categoryId] ?? 0) + entry.amountMinor;
    counts[entry.categoryId] = (counts[entry.categoryId] ?? 0) + 1;
  }

  final List<CategorySpend> rows = <CategorySpend>[];
  amounts.forEach((String id, int amount) {
    final AppCategory category =
        byId[id] ??
        AppCategory(
          id: id,
          name: id,
          icon: 'other',
          colorHex: '#6B7684',
          kind: CategoryKind.expense,
        );
    rows.add(
      CategorySpend(
        category: category,
        amountMinor: amount,
        entries: counts[id] ?? 0,
      ),
    );
  });
  rows.sort(
    (CategorySpend a, CategorySpend b) =>
        b.amountMinor.compareTo(a.amountMinor),
  );
  return rows;
}

/// The shape of the month: how many days cost nothing, what an average day came
/// to, and which single day was the expensive one.
class MonthRhythm {
  const MonthRhythm({
    required this.days,
    required this.noSpendDays,
    required this.totalMinor,
    required this.biggestDay,
  });

  final int days;
  final int noSpendDays;
  final int totalMinor;
  final DayTotal? biggestDay;

  int get averagePerDay => days == 0 ? 0 : totalMinor ~/ days;
}

MonthRhythm monthRhythm(
  List<TransactionEntry> entries, {
  required DateTime from,
  required DateTime toExclusive,
  required DateTime now,
}) {
  final List<DayTotal> days = dailyTotals(
    entries,
    from: from,
    toExclusive: toExclusive,
  ).where((DayTotal day) => !day.day.isAfter(startOfDay(now))).toList();

  DayTotal? biggest;
  int total = 0;
  int quiet = 0;
  for (final DayTotal day in days) {
    total += day.expenseMinor;
    if (day.expenseMinor == 0) quiet++;
    if (biggest == null || day.expenseMinor > biggest.expenseMinor) {
      if (day.expenseMinor > 0) biggest = day;
    }
  }

  return MonthRhythm(
    days: days.length,
    noSpendDays: quiet,
    totalMinor: total,
    biggestDay: biggest,
  );
}
