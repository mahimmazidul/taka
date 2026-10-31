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

/// A category, a group of categories, or an income source.
///
/// Two levels only, on purpose: a group (মেইন কোর্স, ড্রিংকস, স্ন্যাকস…) holds
/// items (ভাত, মাছ, ড্রিংকো…), and an item is what a transaction points at.
/// A category with [parentId] `null` and [isGroup] `false` is a standalone item
/// (Dining out, Laundry, Other) that can be logged directly.
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
    this.parentId,
    this.isGroup = false,
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

  /// Id of the group this item belongs to, or `null` at the top level.
  final String? parentId;

  /// Groups are containers: they roll up their children's spend and can carry
  /// their own monthly limit, but you do not log an entry against them.
  final bool isGroup;

  Color get color => colorFromHex(colorHex);

  /// What the user actually sees: Bangla first, English as the fallback.
  String get label => nameBn.trim().isNotEmpty ? nameBn : name;

  IconData get iconData => categoryIcon(icon);

  bool get hasBudget => (budgetMinor ?? 0) > 0;

  bool get isIncome => kind == CategoryKind.income;

  /// Top-level item: no parent and not a group. Dining out and Other are these.
  bool get isStandalone => parentId == null && !isGroup;

  /// Anything a transaction may point at.
  bool get isLoggable => !isGroup;

  AppCategory copyWith({
    String? name,
    String? nameBn,
    String? icon,
    String? colorHex,
    CategoryKind? kind,
    int? budgetMinor,
    bool clearBudget = false,
    int? sortOrder,
    String? parentId,
    bool moveToTopLevel = false,
    bool? isGroup,
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
      parentId: moveToTopLevel ? null : (parentId ?? this.parentId),
      isGroup: isGroup ?? this.isGroup,
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
      parentId: map['parent_id'] as String?,
      isGroup: ((map['is_group'] as int?) ?? 0) == 1,
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
      'parent_id': parentId,
      'is_group': isGroup ? 1 : 0,
    };
  }
}
