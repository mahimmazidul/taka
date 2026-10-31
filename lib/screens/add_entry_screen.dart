import 'package:flutter/material.dart';

import '../components/amount_keypad.dart';
import '../components/category_picker.dart';
import '../components/primary_button.dart';
import '../components/segmented.dart';
import '../core/app_theme.dart';
import '../models/app_category.dart';
import '../models/meal_slot.dart';
import '../models/transaction_entry.dart';
import '../store/app_state.dart';
import '../utils/date_helpers.dart';
import '../utils/format_currency.dart';
import '../core/clock.dart';

/// Add or edit one entry. Custom keypad, so the numbers stay big and the
/// system keyboard never covers the form while you punch in an amount.
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
  String _amountText = '';
  MealSlot? _meal;

  bool get _isEditing => widget.entry != null;

  int get _amountMinor => keypadTextToMinor(_amountText);

  @override
  void initState() {
    super.initState();
    final TransactionEntry? entry = widget.entry;
    _type = entry?.type ?? EntryType.expense;
    _occurredAt = entry?.occurredAt ?? AppClock.now();
    _amountText = entry == null ? '' : minorToKeypadText(entry.amountMinor);
    _note = TextEditingController(text: entry?.note ?? '');
    _categoryId = entry?.categoryId ?? '';
    _meal = entry?.meal ?? MealSlot.guess(_occurredAt);
    _ensureCategory();
  }

  @override
  void dispose() {
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

  void _onDigit(String digit) {
    setState(() {
      if (_amountText.replaceAll('.', '').length >= 9) return;
      if (_amountText == '0') {
        _amountText = digit;
      } else {
        _amountText += digit;
      }
    });
  }

  void _onDecimal() {
    if (_amountText.contains('.')) return;
    setState(() => _amountText = _amountText.isEmpty ? '0.' : '$_amountText.');
  }

  void _onBackspace() {
    if (_amountText.isEmpty) return;
    setState(
      () => _amountText = _amountText.substring(0, _amountText.length - 1),
    );
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
        const SnackBar(content: Text('Enter an amount first')),
      );
      return;
    }
    if (_categoryId.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Pick a category')));
      return;
    }

    final AppState state = AppState.instance;
    if (_isEditing) {
      await state.updateTransaction(
        widget.entry!.copyWith(
          type: _type,
          amountMinor: _amountMinor,
          categoryId: _categoryId,
          note: _note.text,
          occurredAt: _occurredAt,
          meal: _meal,
          clearMeal: _meal == null,
        ),
      );
    } else {
      await state.addTransaction(
        type: _type,
        amountMinor: _amountMinor,
        categoryId: _categoryId,
        note: _note.text,
        occurredAt: _occurredAt,
        meal: _meal,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? 'Entry updated'
              : '${_type == EntryType.expense ? 'Expense' : 'Income'} saved · '
                    '${formatMoney(_amountMinor, symbol: state.currencySymbol)}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
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
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Segmented<EntryType>(
                    value: _type,
                    onChanged: (EntryType value) => setState(() {
                      _type = value;
                      _ensureCategory();
                    }),
                    options: const <SegmentOption<EntryType>>[
                      SegmentOption<EntryType>(
                        value: EntryType.expense,
                        label: 'Expense',
                      ),
                      SegmentOption<EntryType>(
                        value: EntryType.income,
                        label: 'Income',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _SectionLabel(
                          text: _type == EntryType.expense
                              ? 'CATEGORY'
                              : 'SOURCE',
                        ),
                        const SizedBox(height: 8),
                        CategoryPicker(
                          kind: _type == EntryType.expense
                              ? CategoryKind.expense
                              : CategoryKind.income,
                          selectedId: _categoryId.isEmpty ? null : _categoryId,
                          onSelected: (AppCategory category) =>
                              setState(() => _categoryId = category.id),
                        ),
                        if (_type == EntryType.expense) ...<Widget>[
                          const SizedBox(height: 10),
                          const _SectionLabel(text: 'MEAL'),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 36,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: <Widget>[
                                for (final MealSlot slot
                                    in MealSlot.values) ...[
                                  AppChip(
                                    label: slot.label,
                                    selected: _meal == slot,
                                    onTap: () => setState(
                                      () => _meal = _meal == slot ? null : slot,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextField(
                          controller: _note,
                          textInputAction: TextInputAction.done,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            hintText: 'Note — e.g. lunch at the hall canteen',
                            counterText: '',
                            prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DateRow(
                          occurredAt: _occurredAt,
                          onPickDate: _pickDate,
                          onPickTime: _pickTime,
                          onQuickDay: (int daysAgo) => setState(
                            () => _occurredAt = withCurrentTime(
                              AppClock.now().subtract(Duration(days: daysAgo)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                if (!keyboardOpen) ...<Widget>[
                  _AmountDisplay(
                    amountText: _amountText,
                    symbol: symbol,
                    isExpense: _type == EntryType.expense,
                  ),
                  AmountKeypad(
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                    onDecimal: _onDecimal,
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: PrimaryButton(
                    label: _isEditing ? 'Save changes' : 'Save entry',
                    icon: Icons.check_rounded,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({
    required this.amountText,
    required this.symbol,
    required this.isExpense,
  });

  final String amountText;
  final String symbol;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final String shown = amountText.isEmpty ? '0' : amountText;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                symbol,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted(context),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: 46,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.4,
                  color: isExpense
                      ? AppColors.ink(context)
                      : AppColors.income(context),
                ),
                child: Text(shown),
              ),
            ],
          ),
        ),
      ),
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          AppChip(
            label: 'Today',
            selected: isToday,
            onTap: () => onQuickDay(0),
          ),
          const SizedBox(width: 8),
          AppChip(
            label: 'Yesterday',
            selected: isYesterday,
            onTap: () => onQuickDay(1),
          ),
          if (!isToday && !isYesterday) ...<Widget>[
            const SizedBox(width: 8),
            AppChip(
              label: formatDateLabel(occurredAt),
              icon: Icons.calendar_today_rounded,
              selected: true,
              onTap: onPickDate,
            ),
          ] else ...<Widget>[
            const SizedBox(width: 8),
            AppChip(
              label: 'Pick date',
              icon: Icons.calendar_today_rounded,
              onTap: onPickDate,
            ),
          ],
          const SizedBox(width: 8),
          AppChip(
            label: formatTime(occurredAt),
            icon: Icons.schedule_rounded,
            onTap: onPickTime,
          ),
        ],
      ),
    );
  }
}
