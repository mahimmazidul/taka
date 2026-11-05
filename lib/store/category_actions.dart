import '../models/app_category.dart';
import '../models/transaction_entry.dart';
import '../utils/id.dart';
import 'app_state.dart';

/// Category CRUD, budget limits and the protected "Other" fallbacks.
extension CategoryActions on AppState {
  static const String _fallbackExpenseId = 'other';
  static const String _fallbackIncomeId = 'other_income';

  Future<void> saveCategory(AppCategory category) async {
    await categoryRepo.upsert(category);
    await refresh();
  }

  /// Creates an item, or a group when [asGroup] is true.
  ///
  /// Items inherit their group's colour unless one is passed, which keeps a new
  /// "চানাচুর" under Snacks looking like it belongs there.
  Future<AppCategory> createCategory({
    required String name,
    required String nameBn,
    required CategoryKind kind,
    required String icon,
    String? colorHex,
    String? parentId,
    bool asGroup = false,
  }) async {
    final AppCategory? parent = parentId == null
        ? null
        : categoryById(parentId);
    final AppCategory category = AppCategory(
      id: newId(),
      name: name.trim().isEmpty ? nameBn.trim() : name.trim(),
      nameBn: nameBn.trim(),
      icon: icon,
      colorHex: colorHex ?? parent?.colorHex ?? '#6B7684',
      kind: kind,
      sortOrder: await categoryRepo.nextSortOrder(kind),
      parentId: asGroup ? null : parentId,
      isGroup: asGroup,
      // A new item is as edible as the branch it is dropped into. A new group is
      // a container and takes its colour from nothing.
      isFood: !asGroup && (parent?.isFood ?? false),
    );
    await saveCategory(category);
    return category;
  }

  Future<void> setCategoryBudget(String categoryId, int? budgetMinor) async {
    await categoryRepo.setMonthlyBudget(categoryId, budgetMinor);
    await refresh();
  }

  /// Deletes a category after moving its entries to "Other" (expense) or
  /// "Other income". The two fallbacks cannot be deleted.
  ///
  /// Deleting a **group** never deletes its items: they move to the top row and
  /// stay selectable, so a tidy-up can never cost you a category.
  Future<bool> deleteCategory(String categoryId) async {
    final AppCategory? category = categoryById(categoryId);
    if (category == null) return false;
    if (isProtectedCategory(categoryId)) return false;

    if (category.isGroup) {
      await categoryRepo.deleteGroup(categoryId);
      await refresh();
      return true;
    }

    // An item that still has entries must not vanish with its history.
    final String fallback = category.kind == CategoryKind.income
        ? _fallbackIncomeId
        : _fallbackExpenseId;
    await categoryRepo.reassignAndDelete(
      fromCategoryId: categoryId,
      toCategoryId: fallback,
    );
    await refresh();
    return true;
  }

  /// How many entries a category owns — for a group, that includes its items.
  int usageOf(String categoryId) {
    final Set<String> ids = idsUnder(categoryId);
    return allEntries
        .where((TransactionEntry entry) => ids.contains(entry.categoryId))
        .length;
  }

  bool isProtectedCategory(String categoryId) =>
      categoryId == _fallbackExpenseId || categoryId == _fallbackIncomeId;
}
