import 'package:flutter/widgets.dart';

import '../constants/category_icons.dart';
import '../utils/color_hex.dart';

/// Expense categories and income sources share this model; [kind] keeps the two
/// lists apart. Only expense categories can carry a monthly [budgetMinor].
enum CategoryKind {
  expense,
  income;

  static CategoryKind fromDb(Object? value) =>
      value == 'income' ? CategoryKind.income : CategoryKind.expense;

  String get dbValue => name;
}

class AppCategory {
  const AppCategory({
    required this.id,
    required this.name,
    this.nameBn = '',
    required this.icon,
    required this.colorHex,
    required this.kind,
    this.budgetMinor,
    this.sortOrder = 0,
  });

  final String id;

  /// English label, used in the category editor.
  final String name;

  /// Bangla label shown in the UI. Falls back to [name] when empty.
  final String nameBn;

  /// Key into `kCategoryIcons` (see `constants/category_icons.dart`).
  final String icon;
  final String colorHex;
  final CategoryKind kind;
  final int? budgetMinor;
  final int sortOrder;

  Color get color => colorFromHex(colorHex);

  /// What the user actually sees: Bangla first, English as the fallback.
  String get label => nameBn.trim().isNotEmpty ? nameBn : name;

  IconData get iconData => categoryIcon(icon);

  bool get hasBudget => (budgetMinor ?? 0) > 0;

  bool get isIncome => kind == CategoryKind.income;

  AppCategory copyWith({
    String? name,
    String? nameBn,
    String? icon,
    String? colorHex,
    CategoryKind? kind,
    int? budgetMinor,
    bool clearBudget = false,
    int? sortOrder,
  }) {
    return AppCategory(
      id: id,
      name: name ?? this.name,
      nameBn: nameBn ?? this.nameBn,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      kind: kind ?? this.kind,
      budgetMinor: clearBudget ? null : (budgetMinor ?? this.budgetMinor),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  factory AppCategory.fromMap(Map<String, Object?> map) {
    return AppCategory(
      id: map['id']! as String,
      name: map['name']! as String,
      nameBn: (map['name_bn'] as String?) ?? '',
      icon: (map['icon'] as String?) ?? 'other',
      colorHex: (map['color'] as String?) ?? '#6B7684',
      kind: CategoryKind.fromDb(map['kind']),
      budgetMinor: map['budget_minor'] as int?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'name_bn': nameBn,
      'icon': icon,
      'color': colorHex,
      'kind': kind.dbValue,
      'budget_minor': budgetMinor,
      'sort_order': sortOrder,
    };
  }
}
