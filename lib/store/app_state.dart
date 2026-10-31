import 'package:flutter/foundation.dart';

import '../db/category_repository.dart';
import '../db/settings_repository.dart';
import '../db/transaction_repository.dart';
import '../db/udhar_repository.dart';
import '../models/app_category.dart';
import '../models/app_settings.dart';
import '../models/budget_progress.dart';
import '../models/period_totals.dart';
import '../models/transaction_entry.dart';
import '../models/udhar_entry.dart';
import '../utils/budget_calculator.dart';
import '../utils/date_helpers.dart';
import '../utils/id.dart';

/// The app's single source of UI truth.
///
/// A plain [ChangeNotifier] instead of a state-management package: one
/// instance, one `AnimatedBuilder` per screen. Every mutation writes to SQLite
/// first, then reloads the derived numbers, so the UI can never drift from the
/// file. Feature-specific actions live in the `store/*_actions.dart`
/// extensions to keep this file readable.
class AppState extends ChangeNotifier {
  AppState({
    TransactionRepository? transactions,
    CategoryRepository? categories,
    UdharRepository? udhar,
    SettingsRepository? settings,
    DateTime Function()? clock,
  })  : transactions = transactions ?? TransactionRepository(),
        categoryRepo = categories ?? CategoryRepository(),
        udharRepo = udhar ?? UdharRepository(),
        settingsRepo = settings ?? SettingsRepository(),
        _clock = clock ?? DateTime.now;

  /// Swappable so widget tests can point the UI at a throwaway database.
  static AppState instance = AppState();

  final TransactionRepository transactions;
  final CategoryRepository categoryRepo;
  final UdharRepository udharRepo;
  final SettingsRepository settingsRepo;
  final DateTime Function() _clock;

  AppSettings settings = const AppSettings();
  List<AppCategory> categories = const <AppCategory>[];
  PeriodTotals today = const PeriodTotals.empty();
  PeriodTotals week = const PeriodTotals.empty();
  PeriodTotals month = const PeriodTotals.empty();
  PeriodTotals allTime = const PeriodTotals.empty();
  List<DailyTotal> lastSevenDays = const <DailyTotal>[];
  List<BudgetProgress> budgets = const <BudgetProgress>[];
  Map<String, int> monthSpend = const <String, int>{};
  List<TransactionEntry> recentEntries = const <TransactionEntry>[];
  List<TransactionEntry> allEntries = const <TransactionEntry>[];
  List<UdharEntry> udharEntries = const <UdharEntry>[];
  UdharTotals udharTotals = const UdharTotals.empty();
  bool isLoading = true;

  DateTime get now => _clock();

  String get currencySymbol => settings.currencySymbol;

  bool get hasNoEntries => allTime.isEmpty;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    await _reload();
    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _reload();
    notifyListeners();
  }

  Future<void> _reload() async {
    final DateTime now = _clock();

    settings = await settingsRepo.read();
    categories = await categoryRepo.all();

    today = await transactions.totals(startOfDay(now), startOfNextDay(now));
    week = await transactions.totals(
      startOfWeek(now),
      startOfWeek(now).add(const Duration(days: 7)),
    );
    month = await transactions.totals(startOfMonth(now), startOfNextMonth(now));
    allTime = await transactions.totals(DateTime(2000), startOfNextDay(now));

    lastSevenDays = await transactions.dailySeries(
      startOfDay(now).subtract(const Duration(days: 6)),
      7,
    );
    recentEntries = await transactions.recent(limit: 5);
    // The whole ledger in memory: a personal book is small, and History can
    // then filter instantly instead of waiting on a query per keystroke.
    allEntries = await transactions.query(const TransactionQuery());

    final Map<String, int> spentThisMonth = await transactions.expenseByCategory(
      startOfMonth(now),
      startOfNextMonth(now),
    );
    monthSpend = spentThisMonth;
    budgets = buildBudgetProgress(
      categories: categories,
      spentByCategoryMinor: spentThisMonth,
    );

    if (settings.udharEnabled) {
      udharEntries = await udharRepo.all();
      udharTotals = await udharRepo.outstandingTotals();
    } else {
      udharEntries = const <UdharEntry>[];
      udharTotals = const UdharTotals.empty();
    }
  }

  AppCategory? categoryById(String id) {
    for (final AppCategory category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  List<AppCategory> categoriesForKind(CategoryKind kind) => categories
      .where((AppCategory category) => category.kind == kind)
      .toList(growable: false);

  /// Applies and persists settings, then notifies listeners.
  Future<void> applySettings(AppSettings next) async {
    settings = next;
    notifyListeners();
    await settingsRepo.write(next);
  }

  Future<void> addTransaction({
    required EntryType type,
    required int amountMinor,
    required String categoryId,
    required String note,
    required DateTime occurredAt,
  }) async {
    final DateTime now = _clock();
    await transactions.insert(
      TransactionEntry(
        id: newId(),
        type: type,
        amountMinor: amountMinor,
        categoryId: categoryId,
        note: note.trim(),
        occurredAt: occurredAt,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await refresh();
  }

  Future<void> updateTransaction(TransactionEntry entry) async {
    await transactions.update(entry.copyWith(updatedAt: _clock()));
    await refresh();
  }

  Future<void> deleteTransaction(String id) async {
    await transactions.delete(id);
    await refresh();
  }

  /// In-memory filter used by History — same rules as the SQL query.
  List<TransactionEntry> filterEntries({
    EntryType? type,
    String? categoryId,
    String search = '',
    DateTime? from,
    DateTime? toExclusive,
  }) {
    final String needle = search.trim().toLowerCase();
    return allEntries.where((TransactionEntry entry) {
      if (type != null && entry.type != type) return false;
      if (categoryId != null && entry.categoryId != categoryId) return false;
      if (needle.isNotEmpty && !entry.note.toLowerCase().contains(needle)) return false;
      if (from != null && entry.occurredAt.isBefore(from)) return false;
      if (toExclusive != null && !entry.occurredAt.isBefore(toExclusive)) return false;
      return true;
    }).toList(growable: false);
  }

  /// Everything the history screen needs, already filtered by SQL.
  Future<List<TransactionEntry>> queryTransactions(TransactionQuery query) =>
      transactions.query(query);
}
