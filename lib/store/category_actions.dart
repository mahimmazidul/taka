import '../models/app_category.dart';
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

  Future<AppCategory> createCategory({
    required String name,
    required String nameBn,
    required CategoryKind kind,
    required String icon,
    required String colorHex,
  }) async {
    final AppCategory category = AppCategory(
      id: newId(),
      name: name.trim().isEmpty ? nameBn.trim() : name.trim(),
      nameBn: nameBn.trim(),
      icon: icon,
      colorHex: colorHex,
      kind: kind,
      sortOrder: await categoryRepo.nextSortOrder(kind),
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
  Future<bool> deleteCategory(String categoryId) async {
    final AppCategory? category = categoryById(categoryId);
    if (category == null) return false;

    final String fallback = category.kind == CategoryKind.income
        ? _fallbackIncomeId
        : _fallbackExpenseId;
    if (categoryId == fallback) return false;

    await categoryRepo.reassignAndDelete(
      fromCategoryId: categoryId,
      toCategoryId: fallback,
    );
    await refresh();
    return true;
  }

  bool isProtectedCategory(String categoryId) =>
      categoryId == _fallbackExpenseId || categoryId == _fallbackIncomeId;
}
