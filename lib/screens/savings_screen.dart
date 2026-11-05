import 'package:flutter/material.dart';

import '../components/app_sheet.dart';
import '../components/empty_state.dart';
import '../components/entry_row.dart';
import '../components/primary_button.dart';
import '../components/section_title.dart';
import '../core/app_theme.dart';
import '../core/clock.dart';
import '../core/motion.dart';
import '../models/savings_entry.dart';
import '../store/app_state.dart';
import '../store/savings_actions.dart';
import '../utils/date_helpers.dart';
import '../utils/format_currency.dart';
import '../utils/money_input_formatter.dart';
import '../utils/responsive.dart';

/// The savings pot: what has been set aside, what it is for, and the history.
///
/// Deliberately quiet — one number, one bar, two buttons. Money set aside is
/// meant to be forgotten about, not gamified.
class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  Future<void> _move(BuildContext context, SavingsDirection direction) async {
    final TextEditingController amount = TextEditingController();
    final TextEditingController note = TextEditingController();
    final AppState state = AppState.instance;

    await showAppSheet<void>(
      context: context,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SheetTitle(
              title: direction == SavingsDirection.aside
                  ? 'Set money aside'
                  : 'Take money back',
              subtitle: direction == SavingsDirection.aside
                  ? 'Still yours, just not in your pocket'
                  : 'Coming out of the ${formatMoney(state.savingsMinor, symbol: state.currencySymbol)} you saved',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('savings_amount'),
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <MoneyInputFormatter>[MoneyInputFormatter()],
              decoration: InputDecoration(
                hintText: 'Amount',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 6),
                  child: Text(
                    state.currencySymbol,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.muted(context),
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              decoration: const InputDecoration(hintText: 'Note (optional)'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: direction == SavingsDirection.aside
                  ? 'Set aside'
                  : 'Take back',
              icon: direction == SavingsDirection.aside
                  ? Icons.savings_outlined
                  : Icons.undo_rounded,
              onPressed: () async {
                final int minor = parseAmountToMinor(amount.text) ?? 0;
                if (minor <= 0) return;
                await state.addSavings(
                  direction: direction,
                  amountMinor: minor,
                  note: note.text,
                  occurredAt: AppClock.now(),
                );
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setGoal(BuildContext context) async {
    final AppState state = AppState.instance;
    final TextEditingController amount = TextEditingController();
    final TextEditingController label = TextEditingController(
      text: state.settings.savingsGoalLabel ?? '',
    );

    await showAppSheet<void>(
      context: context,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SheetTitle(
              title: 'What are you saving for?',
              subtitle: 'Optional — leave the amount empty to clear it',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: label,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Laptop, trip, book…',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <MoneyInputFormatter>[MoneyInputFormatter()],
              decoration: const InputDecoration(hintText: 'Target amount'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Save goal',
              icon: Icons.check_rounded,
              onPressed: () async {
                await state.setSavingsGoal(
                  amountMinor: parseAmountToMinor(amount.text),
                  label: label.text,
                );
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings')),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (BuildContext context, Widget? _) {
          final AppState state = AppState.instance;
          final String symbol = state.currencySymbol;
          final int saved = state.savingsMinor;
          final int? goal = state.settings.savingsGoalMinor;
          final double gutter = Screen.of(context).gutter;

          return ListView(
            padding: EdgeInsets.only(
              top: 6,
              bottom: 28,
              left: gutter,
              right: gutter,
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'SET ASIDE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: AppColors.muted(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedMoney(
                      saved,
                      symbol: symbol,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        color: AppColors.ink(context),
                      ),
                    ),
                    Text(
                      saved == 0
                          ? 'Nothing in the pot yet'
                          : 'Not counted as spending, and not in your pocket',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (goal != null) ...<Widget>[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              state.settings.savingsGoalLabel ?? 'Goal',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink(context),
                              ),
                            ),
                          ),
                          Text(
                            '${formatMoney(saved, symbol: symbol)} of '
                            '${formatMoney(goal, symbol: symbol)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: saved >= goal
                                  ? Palette.taka
                                  : AppColors.muted(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: goal == 0 ? 0 : (saved / goal).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: AppColors.line(context),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Palette.taka,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: <Widget>[
                    PrimaryButton(
                      label: 'Set money aside',
                      icon: Icons.savings_outlined,
                      onPressed: () => _move(context, SavingsDirection.aside),
                    ),
                    if (saved > 0)
                      TextButton(
                        onPressed: () => _move(context, SavingsDirection.back),
                        child: const Text('Take money back'),
                      ),
                    if (saved == 0) const SizedBox(height: 4),
                  ],
                ),
              ),
              SectionTitle(
                title: 'History',
                actionLabel: goal == null ? 'Set a goal' : 'Change goal',
                onAction: () => _setGoal(context),
              ),
              if (state.savingsEntries.isEmpty)
                const EmptyState(
                  icon: Icons.savings_outlined,
                  title: 'No movements yet',
                  message:
                      'Set money aside when a month goes well, take it back '
                      'when a month does not.',
                )
              else
                for (final SavingsEntry entry
                    in state.savingsEntries) ...<Widget>[
                  _SavingsRow(entry: entry, symbol: symbol),
                  const Hairline(indent: 20),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _SavingsRow extends StatelessWidget {
  const _SavingsRow({required this.entry, required this.symbol});

  final SavingsEntry entry;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final bool aside = entry.direction == SavingsDirection.aside;
    return Pressable(
      onTap: () async {
        final bool? remove = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Remove this movement?'),
            content: const Text(
              'The amount goes back to where it was. Nothing is deleted from '
              'your spending.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (remove == true) {
          await AppState.instance.deleteSavings(entry.id);
        }
      },
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(
              aside ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 18,
              color: aside ? Palette.taka : AppColors.muted(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    aside ? 'Set aside' : 'Took back',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink(context),
                    ),
                  ),
                  Text(
                    entry.note.isEmpty
                        ? formatDateLabel(entry.occurredAt)
                        : '${formatDateLabel(entry.occurredAt)} · ${entry.note}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${aside ? '+' : '−'}${formatMoney(entry.amountMinor, symbol: symbol)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: aside ? Palette.taka : AppColors.ink(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
