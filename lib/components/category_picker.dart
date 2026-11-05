import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/app_category.dart';
import '../store/app_state.dart';
import 'segmented.dart';

/// Two rows of chips: groups on top, that group's items underneath.
///
/// The group you used last opens first, so the common path is **one tap** —
/// open the screen, tap ভাত, save. Leaf groups (Dining out, Other) are logged
/// straight from the top row.
class CategoryPicker extends StatefulWidget {
  const CategoryPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.kind = CategoryKind.expense,
  });

  final String? selectedId;
  final ValueChanged<AppCategory> onSelected;
  final CategoryKind kind;

  @override
  State<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<CategoryPicker> {
  String? _openGroupId;

  /// The top row is a horizontal scroll, and seventeen groups do not fit on a
  /// phone. Without this, opening the screen on the last-used group left its chip
  /// off-screen on the right: the items below were visible, the chip that owned
  /// them was not, and the group read as missing. One key per chip so the open one
  /// can be brought into view.
  final Map<String, GlobalKey> _chipKeys = <String, GlobalKey>{};
  String? _scrolledTo;

  @override
  void initState() {
    super.initState();
    _openGroupId = _groupForSelection();
    _scrollToOpenGroupAfterFrame();
  }

  /// Brings the open group's chip into view, once per group it opens.
  void _scrollToOpenGroupAfterFrame() {
    final String? id = _openGroupId;
    if (id == null || _scrolledTo == id) return;
    _scrolledTo = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? chip = _chipKeys[id]?.currentContext;
      if (chip == null || !mounted) return;
      Scrollable.ensureVisible(
        chip,
        alignment: 0.5,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Which group's items should be showing right now.
  String? _groupForSelection() {
    final AppState state = AppState.instance;
    final AppCategory? selected = widget.selectedId == null
        ? null
        : state.categoryById(widget.selectedId!);
    if (selected != null && selected.parentId != null) {
      return selected.parentId;
    }
    final String? last = state.settings.lastCategoryId;
    final AppCategory? remembered = last == null
        ? null
        : state.categoryById(last);
    if (remembered != null) {
      return remembered.parentId ?? remembered.id;
    }
    final List<AppCategory> groups = state.expenseGroups;
    return groups.isEmpty ? null : groups.first.id;
  }

  void _open(String groupId) {
    setState(() => _openGroupId = groupId);
    _scrollToOpenGroupAfterFrame();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (BuildContext context, Widget? _) {
        final AppState state = AppState.instance;
        final bool isExpense = widget.kind == CategoryKind.expense;
        final List<AppCategory> tops = isExpense
            ? <AppCategory>[...state.expenseGroups, ...state.standaloneExpense]
            : state.categoriesForKind(CategoryKind.income);

        final String? openGroup = _openGroupId;
        final List<AppCategory> items = openGroup == null
            ? const <AppCategory>[]
            : state.childrenOf(openGroup);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 40,
              // A Row rather than a lazy ListView: ensureVisible cannot scroll to
              // a chip that has never been built, and seventeen chips are cheap.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                child: Row(
                  children: <Widget>[
                    for (final AppCategory group in tops) ...<Widget>[
                      if (group != tops.first) const SizedBox(width: 8),
                      KeyedSubtree(
                        key: _chipKeys.putIfAbsent(group.id, () => GlobalKey()),
                        child: AppChip(
                          label: group.label,
                          icon: group.iconData,
                          tint: group.color,
                          selected:
                              group.id == openGroup ||
                              (widget.selectedId != null &&
                                  state
                                      .idsUnder(group.id)
                                      .contains(widget.selectedId)),
                          onTap: () {
                            // A container opens its items; a leaf is the category
                            // itself, so picking the chip is picking it.
                            _open(group.id);
                            if (!group.isGroup) widget.onSelected(group);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (items.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  child: Row(
                    children: <Widget>[
                      for (final AppCategory item in items) ...<Widget>[
                        if (item != items.first) const SizedBox(width: 8),
                        AppChip(
                          label: item.label,
                          icon: item.iconData,
                          tint: item.color,
                          selected: item.id == widget.selectedId,
                          onTap: () => widget.onSelected(item),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The category an entry should start on: the last one used, else the first
/// expense item, so the form is never in an invalid state.
AppCategory? defaultCategoryFor(AppState state, CategoryKind kind) {
  final String? last = state.settings.lastCategoryId;
  final AppCategory? remembered = last == null
      ? null
      : state.categoryById(last);
  if (remembered != null && remembered.kind == kind) return remembered;

  // Fall back to the first item of the first group (Main course → ভাত) rather
  // than whichever category happens to sort first alphabetically.
  for (final AppCategory group in state.expenseGroups) {
    if (group.kind != kind) continue;
    final List<AppCategory> children = state.childrenOf(group.id);
    if (children.isNotEmpty) return children.first;
  }
  final List<AppCategory> items = state.categories
      .where((AppCategory c) => c.kind == kind && c.isLoggable)
      .toList(growable: false);
  return items.isEmpty ? null : items.first;
}

/// Muted helper text under the picker: "Main course · 3rd of the month" style
/// context without adding another box.
class PickerHint extends StatelessWidget {
  const PickerHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11.5, color: AppColors.muted(context)),
    );
  }
}
