import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/category_picker.dart';
import '../components/segmented.dart';
import '../core/app_theme.dart';
import '../core/motion.dart';
import '../core/clock.dart';
import '../models/app_category.dart';
import '../models/meal_slot.dart';
import '../models/transaction_entry.dart';
import '../store/app_state.dart';
import '../utils/date_helpers.dart';
import '../utils/format_currency.dart';
import '../utils/responsive.dart';

/// Add or edit one entry.
///
/// Adding never throws you out: dinner is ভাত plus মাছ plus a drink, so after
/// saving the screen clears the amount and the note, keeps the category and the
/// meal, and shows what you just logged. Only [Done] (or the back arrow) leaves.
class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key, this.entry});

  /// Null = new entry, non-null = edit that entry.
  final TransactionEntry? entry;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  late EntryType _type;
  late DateTime _occurredAt;
  late TextEditingController _note;
  String _categoryId = '';
  late final TextEditingController _amount;
  MealSlot? _meal;

  /// What the last tap on Save actually wrote, shown until the next one.
  String? _added;
  int _addedCount = 0;

  bool get _isEditing => widget.entry != null;

  int get _amountMinor => keypadTextToMinor(_amount.text);

  bool get _isFood => AppState.instance.acceptsMeal(_categoryId);

  @override
  void initState() {
    super.initState();
    final TransactionEntry? entry = widget.entry;
    _type = entry?.type ?? EntryType.expense;
    _occurredAt = entry?.occurredAt ?? AppClock.now();
    _amount = TextEditingController(
      text: entry == null ? '' : minorToKeypadText(entry.amountMinor),
    );
    _note = TextEditingController(text: entry?.note ?? '');
    // Save is enabled by the amount, so the screen has to know when the field
    // changes. Without this listener the button stayed grey until some other
    // rebuild happened.
    _amount.addListener(_onAmountChanged);
    _categoryId = entry?.categoryId ?? '';
    _ensureCategory();
    // Only a food category gets a meal, and only if the saved entry had one.
    _meal = entry?.meal ?? (_isFood ? MealSlot.guess(_occurredAt) : null);
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amount.removeListener(_onAmountChanged);
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _ensureCategory() {
    final AppState state = AppState.instance;
    if (_categoryId.isNotEmpty && state.categoryById(_categoryId) != null) {
      return;
    }
    final CategoryKind kind = _type == EntryType.expense
        ? CategoryKind.expense
        : CategoryKind.income;
    _categoryId = defaultCategoryFor(state, kind)?.id ?? '';
  }

  void _selectCategory(AppCategory category) {
    setState(() {
      _categoryId = category.id;
      // Cosmetics are not eaten: switching to a non-food item drops the meal
      // instead of quietly counting money into breakfast.
      if (!category.isFood) _meal = null;
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: AppClock.now().add(const Duration(days: 1)),
      builder: (BuildContext context, Widget? child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme
              .copyWith(primary: Palette.taka),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _occurredAt = withCurrentTime(picked));
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (picked != null) {
      setState(() {
        _occurredAt = DateTime(
          _occurredAt.year,
          _occurredAt.month,
          _occurredAt.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (_amountMinor <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Type an amount first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_categoryId.isEmpty) return;

    final AppState state = AppState.instance;
    final MealSlot? meal = _isFood ? _meal : null;

    if (_isEditing) {
      await state.updateTransaction(
        widget.entry!.copyWith(
          type: _type,
          amountMinor: _amountMinor,
          categoryId: _categoryId,
          note: _note.text,
          occurredAt: _occurredAt,
          meal: meal,
          clearMeal: meal == null,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Entry updated'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final int addedMinor = _amountMinor;
    final String label = state.categoryById(_categoryId)?.label ?? '';
    await state.addTransaction(
      type: _type,
      amountMinor: addedMinor,
      categoryId: _categoryId,
      note: _note.text,
      occurredAt: _occurredAt,
      meal: meal,
    );
    if (!mounted) return;

    // Stay here. Clear what should not repeat, keep what should: the category,
    // the meal and the date are the combo you are still eating.
    setState(() {
      _addedCount++;
      _added =
          '$label · ${formatMoney(addedMinor, symbol: state.currencySymbol)}';
      _amount.clear();
      _note.clear();
    });
  }

  Future<void> _delete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('This cannot be undone.'),
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
    if (confirmed != true || !mounted) return;
    await AppState.instance.deleteTransaction(widget.entry!.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Screen screen = Screen.of(context);
    final String symbol = AppState.instance.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditing ? 'Edit entry' : 'New entry'),
        actions: <Widget>[
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: Palette.expense,
              onPressed: _delete,
            ),
          if (!_isEditing)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Done',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: screen.font(14, context),
                  fontWeight: FontWeight.w600,
                  color: Palette.taka,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Landscape or a tablet: form on the left, pad on the right, so the
            // keyboard-height screen is not wasted.
            final bool twoPanes = screen.useTwoPanes;
            final Widget form = _Form(
              type: _type,
              onTypeChanged: (EntryType value) => setState(() {
                _type = value;
                _ensureCategory();
                if (!_isFood) _meal = null;
              }),
              categoryId: _categoryId,
              onCategorySelected: _selectCategory,
              showMeal: _type == EntryType.expense && _isFood,
              meal: _meal,
              onMealChanged: (MealSlot? slot) => setState(() => _meal = slot),
              note: _note,
              occurredAt: _occurredAt,
              onPickDate: _pickDate,
              onPickTime: _pickTime,
              onQuickDay: (int daysAgo) => setState(
                () => _occurredAt = withCurrentTime(
                  AppClock.now().subtract(Duration(days: daysAgo)),
                ),
              ),
            );

            final Widget amountBlock = _AmountBlock(
              controller: _amount,
              symbol: symbol,
              added: _added,
              addedCount: _addedCount,
              isExpense: _type == EntryType.expense,
              saveLabel: _isEditing ? 'Save' : 'Add',
              enabled: _amountMinor > 0 && _categoryId.isNotEmpty,
              autofocus: !_isEditing,
              onSave: _save,
            );

            if (twoPanes) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(4, 4, 8, 12),
                        child: form,
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: amountBlock,
                      ),
                    ),
                  ],
                ),
              );
            }

            // One scrolling column: form, then amount and Save. Nothing is
            // pinned, so a tall phone has no dead space at the bottom, and when
            // the keyboard opens Flutter scrolls the focused field into view —
            // Save rides with it, still under the thumb.
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                screen.px(20),
                4,
                screen.px(20),
                screen.px(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  form,
                  SizedBox(height: screen.px(18)),
                  amountBlock,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The form half: what, which category, which meal, a note, when.
class _Form extends StatelessWidget {
  const _Form({
    required this.type,
    required this.onTypeChanged,
    required this.categoryId,
    required this.onCategorySelected,
    required this.showMeal,
    required this.meal,
    required this.onMealChanged,
    required this.note,
    required this.occurredAt,
    required this.onPickDate,
    required this.onPickTime,
    required this.onQuickDay,
  });

  final EntryType type;
  final ValueChanged<EntryType> onTypeChanged;
  final String categoryId;
  final ValueChanged<AppCategory> onCategorySelected;
  final bool showMeal;
  final MealSlot? meal;
  final ValueChanged<MealSlot?> onMealChanged;
  final TextEditingController note;
  final DateTime occurredAt;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final ValueChanged<int> onQuickDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Segmented<EntryType>(
          value: type,
          onChanged: onTypeChanged,
          options: const <SegmentOption<EntryType>>[
            SegmentOption<EntryType>(
              value: EntryType.expense,
              label: 'Expense',
            ),
            SegmentOption<EntryType>(value: EntryType.income, label: 'Income'),
          ],
        ),
        const SizedBox(height: 14),
        _SectionLabel(text: type == EntryType.expense ? 'CATEGORY' : 'SOURCE'),
        const SizedBox(height: 8),
        CategoryPicker(
          kind: type == EntryType.expense
              ? CategoryKind.expense
              : CategoryKind.income,
          selectedId: categoryId.isEmpty ? null : categoryId,
          onSelected: onCategorySelected,
        ),
        // Only food gets a meal. A face wash or a notebook has no business in
        // the breakfast total, so the row simply is not there.
        if (showMeal) ...<Widget>[
          const SizedBox(height: 10),
          const _SectionLabel(text: 'MEAL'),
          const SizedBox(height: 6),
          // Three chips in a Wrap. This used to be a fixed-height horizontal
          // ListView inside the form's vertical one: two scroll axes in a 36 px
          // strip, which is why the row felt broken and cut off.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final MealSlot slot in MealSlot.values)
                AppChip(
                  label: slot.label,
                  selected: meal == slot,
                  onTap: () => onMealChanged(meal == slot ? null : slot),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: note,
          textInputAction: TextInputAction.done,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'Note — e.g. lunch at the hall canteen',
            counterText: '',
            prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        _DateRow(
          occurredAt: occurredAt,
          onPickDate: onPickDate,
          onPickTime: onPickTime,
          onQuickDay: onQuickDay,
        ),
      ],
    );
  }
}

/// The amount and the Save button.
///
/// The number is a real text field using the phone's own numeric keyboard: the
/// keys are the size the OS says they should be, the digits are familiar, and
/// there is nothing to get wrong at 2 a.m. It keeps focus after saving, so a
/// second entry is type–tap–type–tap.
class _AmountBlock extends StatelessWidget {
  const _AmountBlock({
    required this.controller,
    required this.symbol,
    required this.added,
    required this.addedCount,
    required this.isExpense,
    required this.saveLabel,
    required this.enabled,
    required this.autofocus,
    required this.onSave,
  });

  final TextEditingController controller;
  final String symbol;
  final String? added;
  final int addedCount;
  final bool isExpense;
  final String saveLabel;
  final bool enabled;
  final bool autofocus;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final Screen screen = Screen.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 26,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: added == null
                ? const SizedBox.shrink()
                : Row(
                    key: ValueKey<String>('$added-$addedCount'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: Palette.taka,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Added $added',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Palette.taka,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: screen.px(14)),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(screen.px(18)),
            border: Border.all(color: AppColors.line(context)),
          ),
          child: Row(
            children: <Widget>[
              Text(
                symbol,
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: screen.font(20, context),
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('amount'),
                  controller: controller,
                  autofocus: autofocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSave(),
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: screen.font(34, context),
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: isExpense ? AppColors.ink(context) : Palette.taka,
                  ),
                  // The app theme gives every field an outline; inside this
                  // pill it would draw a box in a box.
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '0',
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    LengthLimitingTextInputFormatter(9),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: screen.px(8)),
        Pressable(
          onTap: enabled ? onSave : null,
          scale: 0.98,
          child: Container(
            height: screen.px(52).clamp(46.0, 58.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: enabled
                    ? const <Color>[Color(0xFF14A98B), Palette.takaDeep]
                    : <Color>[
                        Palette.taka.withValues(alpha: 0.30),
                        Palette.takaDeep.withValues(alpha: 0.30),
                      ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(screen.px(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.check_rounded,
                  size: screen.font(18, context),
                  color: Colors.white,
                ),
                const SizedBox(width: 7),
                Text(
                  saveLabel.toUpperCase(),
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: screen.font(13, context),
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Small uppercase label used above the category and meal rows.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 10.5,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.muted(context),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.occurredAt,
    required this.onPickDate,
    required this.onPickTime,
    required this.onQuickDay,
  });

  final DateTime occurredAt;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final ValueChanged<int> onQuickDay;

  @override
  Widget build(BuildContext context) {
    final bool isToday = isSameDay(occurredAt, AppClock.now());
    final bool isYesterday = isSameDay(
      occurredAt,
      AppClock.now().subtract(const Duration(days: 1)),
    );

    // A Wrap, not a horizontal scroll: four chips were being clipped mid-word at
    // the right edge. On a narrow phone the last one drops to a second line
    // instead, and nothing is ever half visible.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        AppChip(label: 'Today', selected: isToday, onTap: () => onQuickDay(0)),
        AppChip(
          label: 'Yesterday',
          selected: isYesterday,
          onTap: () => onQuickDay(1),
        ),
        if (!isToday && !isYesterday)
          AppChip(
            label: formatDateLabel(occurredAt),
            icon: Icons.calendar_today_rounded,
            selected: true,
            onTap: onPickDate,
          )
        else
          AppChip(
            label: 'Pick date',
            icon: Icons.calendar_today_rounded,
            onTap: onPickDate,
          ),
        AppChip(
          label: formatTime(occurredAt),
          icon: Icons.schedule_rounded,
          onTap: onPickTime,
        ),
      ],
    );
  }
}
