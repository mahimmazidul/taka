import 'package:flutter/material.dart';

import '../constants/category_icons.dart';
import '../core/app_theme.dart';
import '../core/motion.dart';
import '../models/app_category.dart';
import '../store/app_state.dart';
import '../store/category_actions.dart';
import '../components/app_sheet.dart';
import '../components/segmented.dart';
import '../components/primary_button.dart';
import '../utils/color_hex.dart';

/// Create or edit a category: labels (Bangla + English), icon, colour, budget.
Future<void> showCategoryEditor(
  BuildContext context, {
  AppCategory? category,
  required CategoryKind kind,
  String? parentId,
}) async {
  await showAppSheet<void>(
    context: context,
    expand: true,
    builder: (BuildContext context) => _CategoryEditor(
      category: category,
      kind: kind,
      initialParentId: parentId ?? category?.parentId,
    ),
  );
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({
    required this.category,
    required this.kind,
    this.initialParentId,
  });

  final AppCategory? category;
  final CategoryKind kind;
  final String? initialParentId;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final TextEditingController _nameBn = TextEditingController(
    text: widget.category?.nameBn ?? '',
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.category?.name ?? '',
  );
  late String _icon = widget.category?.icon ?? kIconPickerKeys.first;
  late String _color = widget.category?.colorHex ?? kCategoryPalette.first;
  late String? _parentId = widget.initialParentId;
  late bool _asGroup = widget.category?.isGroup ?? false;

  bool get _isNew => widget.category == null;

  Future<void> _save() async {
    final String bn = _nameBn.text.trim();
    final String en = _name.text.trim();
    if (bn.isEmpty && en.isEmpty) return;

    final AppState state = AppState.instance;
    if (_isNew) {
      await state.createCategory(
        name: en,
        nameBn: bn,
        kind: widget.kind,
        icon: _icon,
        colorHex: _color,
        parentId: _asGroup ? null : _parentId,
        asGroup: _asGroup,
      );
    } else {
      // Moving an item into a food group makes it food (and out of one does not
      // silently unmake it if it stays top-level): the branch decides, unless the
      // item has no parent at all, in which case it keeps what it had.
      final AppCategory? parent = _parentId == null
          ? null
          : state.categoryById(_parentId!);
      await state.saveCategory(
        widget.category!.copyWith(
          name: en.isEmpty ? bn : en,
          nameBn: bn,
          icon: _icon,
          colorHex: _color,
          isGroup: _asGroup,
          parentId: _asGroup ? null : _parentId,
          moveToTopLevel: _asGroup || _parentId == null,
          isFood: _asGroup
              ? false
              : (parent?.isFood ?? widget.category!.isFood),
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final AppCategory category = widget.category!;
    final int used = AppState.instance.usageOf(category.id);
    if (!mounted) return;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete ${category.label}?'),
        content: Text(
          category.isGroup
              ? 'The items inside it stay — they move to the top row.'
              : used == 0
              ? 'This category has no entries.'
              : '$used entries will move to "Other" so your ledger stays complete.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Palette.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await AppState.instance.deleteCategory(category.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = colorFromHex(_color);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SheetTitle(
          title: _isNew
              ? (_asGroup ? 'New group' : 'New category')
              : (_asGroup ? 'Edit group' : 'Edit category'),
          subtitle: widget.kind == CategoryKind.expense
              ? (_asGroup
                    ? 'A group holds items and rolls up their spend'
                    : 'Expense category')
              : 'Income source',
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(categoryIcon(_icon), color: accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _nameBn,
                      decoration: const InputDecoration(hintText: 'বাংলা নাম'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'English name'),
              ),
              if (widget.kind == CategoryKind.expense) ...<Widget>[
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(child: _Label('Lives in')),
                    Switch.adaptive(
                      value: _asGroup,
                      activeThumbColor: Palette.taka,
                      onChanged: (bool value) =>
                          setState(() => _asGroup = value),
                    ),
                    Text(
                      'Make it a group',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ),
                if (!_asGroup) ...<Widget>[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      AppChip(
                        label: 'Top level',
                        selected: _parentId == null,
                        onTap: () => setState(() => _parentId = null),
                      ),
                      for (final AppCategory group
                          in AppState.instance.expenseGroups)
                        AppChip(
                          label: group.label,
                          icon: group.iconData,
                          tint: group.color,
                          selected: _parentId == group.id,
                          onTap: () => setState(() {
                            _parentId = group.id;
                            if (_isNew) _color = group.colorHex;
                          }),
                        ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 18),
              _Label('Icon'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String key in kIconPickerKeys)
                    Pressable(
                      onTap: () => setState(() => _icon = key),
                      scale: 0.9,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: key == _icon
                              ? accent.withValues(alpha: 0.16)
                              : AppColors.bg(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: key == _icon
                                ? accent
                                : AppColors.line(context),
                          ),
                        ),
                        child: Icon(
                          categoryIcon(key),
                          size: 20,
                          color: key == _icon
                              ? accent
                              : AppColors.muted(context),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _Label('Colour'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  for (final String hex in kCategoryPalette)
                    Pressable(
                      onTap: () => setState(() => _color = hex),
                      scale: 0.85,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorFromHex(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hex == _color
                                ? AppColors.ink(context)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: <Widget>[
              if (!_isNew &&
                  !AppState.instance.isProtectedCategory(widget.category!.id))
                IconButton(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Palette.expense,
                ),
              Expanded(
                child: PrimaryButton(
                  label: _isNew ? 'Create category' : 'Save changes',
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
        color: AppColors.muted(context),
      ),
    );
  }
}
