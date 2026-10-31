import '../models/app_settings.dart';
import '../utils/currency_catalog.dart';
import 'app_state.dart';

/// Preferences: theme, currency, feature toggles, monthly cap.
extension SettingsActions on AppState {
  Future<void> _save(AppSettings next) => applySettings(next);

  Future<void> setDarkMode(bool value) => _save(settings.copyWith(darkMode: value));

  Future<void> toggleDarkMode() => setDarkMode(!settings.darkMode);

  Future<void> setCurrency(String code) {
    final CurrencyOption option = currencyOption(code);
    return _save(settings.copyWith(currencyCode: code, currencySymbol: option.symbol));
  }

  Future<void> setUdharEnabled(bool value) async {
    await _save(settings.copyWith(udharEnabled: value));
    await refresh();
  }

  Future<void> setBudgetsEnabled(bool value) async {
    await _save(settings.copyWith(budgetsEnabled: value));
    await refresh();
  }

  Future<void> setMonthlyBudget(int? minorUnits) async {
    final AppSettings next = minorUnits == null || minorUnits <= 0
        ? settings.copyWith(clearMonthlyBudget: true)
        : settings.copyWith(monthlyBudgetMinor: minorUnits);
    await _save(next);
    await refresh();
  }
}
