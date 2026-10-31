import 'package:flutter_test/flutter_test.dart';
import 'package:taka/models/app_category.dart';
import 'package:taka/models/app_settings.dart';
import 'package:taka/models/budget_progress.dart';
import 'package:taka/models/day_group.dart';
import 'package:taka/utils/budget_calculator.dart';
import 'package:taka/utils/date_helpers.dart';
import 'package:taka/utils/format_currency.dart';

void main() {
  group('formatMoney', () {
    test('formats whole taka without decimals', () {
      expect(formatMoney(0), '৳ 0');
      expect(formatMoney(125000), '৳ 1,250');
      expect(formatMoney(123456789), '৳ 1,234,567');
    });

    test('formats paisa when asked', () {
      expect(formatMoney(125050, showDecimals: true), '৳ 1,250.50');
      expect(formatMoney(5, showDecimals: true), '৳ 0.05');
    });

    test('signs are outside the symbol', () {
      expect(formatMoney(-25000), '−৳ 250');
      expect(formatMoney(25000, signed: true), '+৳ 250');
    });
  });

  group('compact money', () {
    test('shortens thousands and millions', () {
      expect(formatCompactMoney(1250000), '৳ 12.5k');
      expect(formatCompactMoney(250000000), '৳ 2.5m');
      expect(formatCompactMoney(45000), '৳ 450');
    });
  });

  group('amount parsing', () {
    test('accepts plain, comma and decimal input', () {
      expect(parseAmountToMinor('250'), 25000);
      expect(parseAmountToMinor('1,250.50'), 125050);
      expect(parseAmountToMinor(' 99.99 '), 9999);
    });

    test('rejects empty, zero, negative and junk', () {
      expect(parseAmountToMinor(''), isNull);
      expect(parseAmountToMinor('0'), isNull);
      expect(parseAmountToMinor('-5'), isNull);
      expect(parseAmountToMinor('abc'), isNull);
    });

    test('keypad text converts exactly, without float drift', () {
      expect(keypadTextToMinor(''), 0);
      expect(keypadTextToMinor('7'), 700);
      expect(keypadTextToMinor('0.'), 0);
      expect(keypadTextToMinor('0.1'), 10);
      expect(keypadTextToMinor('0.10'), 10);
      expect(keypadTextToMinor('1234.56'), 123456);
      expect(keypadTextToMinor('1234.567'), 123456); // extra digits ignored
      expect(minorToKeypadText(123456), '1234.56');
      expect(minorToKeypadText(700), '7');
    });
  });

  group('dateHelpers', () {
    test('week starts on Sunday', () {
      expect(startOfWeek(DateTime(2026, 10, 31)), DateTime(2026, 10, 25));
      expect(startOfWeek(DateTime(2026, 10, 25)), DateTime(2026, 10, 25));
    });

    test('month boundaries roll over years', () {
      expect(startOfNextMonth(DateTime(2026, 12, 14)), DateTime(2027, 1, 1));
      expect(formatMonthYear(DateTime(2026, 10, 3)), 'October 2026');
    });

    test('time is 12-hour', () {
      expect(formatTime(DateTime(2026, 10, 31, 0, 5)), '12:05 AM');
      expect(formatTime(DateTime(2026, 10, 31, 19, 42)), '7:42 PM');
    });

    test('friendly labels', () {
      final DateTime now = DateTime.now();
      expect(formatDateLabel(now), 'Today');
      expect(formatDateLabel(now.subtract(const Duration(days: 1))), 'Yesterday');
    });

    test('groups items by day, preserving order', () {
      final List<DateTime> dates = <DateTime>[
        DateTime(2026, 10, 31, 20),
        DateTime(2026, 10, 31, 9),
        DateTime(2026, 10, 30, 12),
      ];
      final List<DayGroup<DateTime>> groups =
          groupByDay<DateTime>(dates, (DateTime d) => d);

      expect(groups.length, 2);
      expect(groups.first.day, DateTime(2026, 10, 31));
      expect(groups.first.items.length, 2);
    });
  });

  group('budgets', () {
    const AppCategory rice = AppCategory(
      id: 'rice',
      name: 'Rice & meal',
      nameBn: 'ভাত',
      icon: 'rice',
      colorHex: '#E9A23B',
      kind: CategoryKind.expense,
      budgetMinor: 2000000,
    );

    test('80% warns, 100% exceeds', () {
      expect(
        const BudgetProgress(category: rice, spentMinor: 100000, budgetMinor: 2000000)
            .status,
        BudgetStatus.ok,
      );
      expect(
        const BudgetProgress(category: rice, spentMinor: 1600000, budgetMinor: 2000000)
            .status,
        BudgetStatus.warning,
      );
      final BudgetProgress over =
          const BudgetProgress(category: rice, spentMinor: 2400000, budgetMinor: 2000000);
      expect(over.status, BudgetStatus.exceeded);
      expect(over.clampedRatio, 1.0);
      expect(over.remainingMinor, -400000);
    });

    test('calculator skips unbudgeted and income categories', () {
      const AppCategory laundry = AppCategory(
        id: 'laundry',
        name: 'Laundry',
        icon: 'laundry',
        colorHex: '#4AA3A2',
        kind: CategoryKind.expense,
      );
      const AppCategory income = AppCategory(
        id: 'tuition',
        name: 'Tuition',
        icon: 'school',
        colorHex: '#3C7EDB',
        kind: CategoryKind.income,
      );

      final List<BudgetProgress> rows = buildBudgetProgress(
        categories: const <AppCategory>[rice, laundry, income],
        spentByCategoryMinor: <String, int>{'rice': 1900000, 'laundry': 50000},
      );

      expect(rows.length, 1);
      expect(rows.single.category.id, 'rice');
      expect(rows.single.status, BudgetStatus.warning);
    });
  });

  group('settings round-trip', () {
    test('survives toMap/fromMap', () {
      const AppSettings original =
          AppSettings(darkMode: true, monthlyBudgetMinor: 5000000);
      final AppSettings restored = AppSettings.fromMap(original.toMap());

      expect(restored.darkMode, isTrue);
      expect(restored.monthlyBudgetMinor, 5000000);
      expect(restored.currencySymbol, '৳');
      expect(restored.udharEnabled, isTrue);
    });
  });

  group('category labels', () {
    test('prefers Bangla, falls back to English', () {
      const AppCategory withBn = AppCategory(
        id: 'a',
        name: 'Laundry',
        nameBn: 'লন্ড্রি',
        icon: 'laundry',
        colorHex: '#4AA3A2',
        kind: CategoryKind.expense,
      );
      const AppCategory withoutBn = AppCategory(
        id: 'b',
        name: 'Laundry',
        icon: 'laundry',
        colorHex: '#4AA3A2',
        kind: CategoryKind.expense,
      );

      expect(withBn.label, 'লন্ড্রি');
      expect(withoutBn.label, 'Laundry');
    });
  });
}
