/// User preferences, persisted as key/value rows in the `settings` table.
/// No secrets are stored here (this build has no PIN, by request).
class AppSettings {
  const AppSettings({
    this.currencyCode = 'BDT',
    this.currencySymbol = '৳',
    this.darkMode = false,
    this.monthlyBudgetMinor,
    this.udharEnabled = true,
    this.budgetsEnabled = true,
    this.lastCategoryId,
  });

  final String currencyCode;
  final String currencySymbol;
  final bool darkMode;

  /// Optional overall monthly spending cap, in minor units (paisa).
  final int? monthlyBudgetMinor;
  final bool udharEnabled;
  final bool budgetsEnabled;

  /// Last item logged, so the add-entry screen can open on the group you used
  /// last instead of making you scroll to it again.
  final String? lastCategoryId;

  AppSettings copyWith({
    String? currencyCode,
    String? currencySymbol,
    bool? darkMode,
    int? monthlyBudgetMinor,
    bool clearMonthlyBudget = false,
    bool? udharEnabled,
    bool? budgetsEnabled,
    String? lastCategoryId,
  }) {
    return AppSettings(
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      darkMode: darkMode ?? this.darkMode,
      monthlyBudgetMinor: clearMonthlyBudget
          ? null
          : (monthlyBudgetMinor ?? this.monthlyBudgetMinor),
      udharEnabled: udharEnabled ?? this.udharEnabled,
      budgetsEnabled: budgetsEnabled ?? this.budgetsEnabled,
      lastCategoryId: lastCategoryId ?? this.lastCategoryId,
    );
  }

  Map<String, String> toMap() {
    return <String, String>{
      'currency_code': currencyCode,
      'currency_symbol': currencySymbol,
      'dark_mode': darkMode ? '1' : '0',
      'monthly_budget_minor': monthlyBudgetMinor?.toString() ?? '',
      'udhar_enabled': udharEnabled ? '1' : '0',
      'budgets_enabled': budgetsEnabled ? '1' : '0',
      'last_category_id': lastCategoryId ?? '',
    };
  }

  factory AppSettings.fromMap(Map<String, String> map) {
    final int? budget = int.tryParse(map['monthly_budget_minor'] ?? '');
    return AppSettings(
      currencyCode: map['currency_code'] ?? 'BDT',
      currencySymbol: map['currency_symbol'] ?? '৳',
      darkMode: (map['dark_mode'] ?? '0') == '1',
      monthlyBudgetMinor: (budget ?? 0) > 0 ? budget : null,
      udharEnabled: (map['udhar_enabled'] ?? '1') == '1',
      budgetsEnabled: (map['budgets_enabled'] ?? '1') == '1',
      lastCategoryId: (map['last_category_id'] ?? '').trim().isEmpty
          ? null
          : map['last_category_id'],
    );
  }
}
