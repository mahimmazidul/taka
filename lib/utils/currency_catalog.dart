/// Currencies offered in Settings. BDT is the default; the symbol drives every
/// formatted amount in the app.
class CurrencyOption {
  const CurrencyOption({
    required this.code,
    required this.name,
    required this.symbol,
  });

  final String code;
  final String name;
  final String symbol;

  String get label => '$code · $symbol $name';
}

const List<CurrencyOption> kCurrencies = <CurrencyOption>[
  CurrencyOption(code: 'BDT', name: 'Bangladeshi Taka', symbol: '৳'),
  CurrencyOption(code: 'INR', name: 'Indian Rupee', symbol: '₹'),
  CurrencyOption(code: 'PKR', name: 'Pakistani Rupee', symbol: '₨'),
  CurrencyOption(code: 'USD', name: 'US Dollar', symbol: r'$'),
  CurrencyOption(code: 'EUR', name: 'Euro', symbol: '€'),
  CurrencyOption(code: 'GBP', name: 'Pound Sterling', symbol: '£'),
];

CurrencyOption currencyOption(String code) {
  for (final CurrencyOption option in kCurrencies) {
    if (option.code == code) return option;
  }
  return kCurrencies.first;
}
