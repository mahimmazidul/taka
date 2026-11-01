import 'package:flutter/material.dart';

import '../components/category_tile.dart';
import '../components/entry_row.dart';
import '../components/section_title.dart';
import '../core/app_theme.dart';
import '../core/clock.dart';
import '../store/app_state.dart';
import '../utils/date_helpers.dart';
import '../utils/format_currency.dart';
import '../utils/insights.dart';
import '../utils/responsive.dart';

/// What the numbers say about the month, in plain figures and thin bars.
///
/// No pie charts and no dashboards: three questions a student actually asks —
/// where did it go, which meals did I not log, and how regular was I.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patterns')),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (BuildContext context, Widget? _) {
          final AppState state = AppState.instance;
          final DateTime now = AppClock.now();
          final DateTime from = startOfMonth(now);
          final DateTime toExclusive = startOfNextMonth(now);
          final String symbol = state.currencySymbol;

          final List<CategorySpend> top = topSpending(
            state.allEntries,
            state.categories,
            from: from,
            toExclusive: toExclusive,
          );
          final List<MealGap> gaps = missedMeals(
            state.allEntries,
            state.categories,
            from: from,
            toExclusive: toExclusive,
            now: now,
          );
          final MonthRhythm rhythm = monthRhythm(
            state.allEntries,
            from: from,
            toExclusive: toExclusive,
            now: now,
          );
          final int spent = state.month.expenseMinor;
          final double gutter = Screen.of(context).gutter;

          return ListView(
            padding: EdgeInsets.only(
              top: 8,
              bottom: 28,
              left: gutter,
              right: gutter,
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Text(
                  formatMonthYear(now),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted(context),
                  ),
                ),
              ),
              const SectionTitle(title: 'Where it went'),
              if (top.isEmpty)
                _Empty(text: 'Nothing spent this month yet.')
              else
                for (int i = 0; i < top.length && i < 6; i++)
                  _CategoryBar(
                    row: top[i],
                    share: spent == 0 ? 0 : top[i].amountMinor / spent,
                    symbol: symbol,
                  ),
              const SizedBox(height: 6),
              const SectionTitle(title: 'Meals'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  'Counted only for food. A day with no entry for a meal shows '
                  'up here — it means "not logged", not "you skipped".',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: AppColors.muted(context),
                  ),
                ),
              ),
              if (gaps.every((MealGap gap) => gap.loggedDays == 0))
                _Empty(
                  text:
                      'No meals tagged yet. Pick breakfast, lunch or dinner '
                      'when you log food and this fills in.',
                )
              else
                for (final MealGap gap in gaps)
                  _MealRow(gap: gap, days: rhythm.days),
              const SizedBox(height: 6),
              const SectionTitle(title: 'Rhythm'),
              _FigureRow(
                figures: <_Figure>[
                  _Figure(
                    label: 'No-spend days',
                    value: '${rhythm.noSpendDays}',
                    hint: 'of ${rhythm.days} so far',
                  ),
                  _Figure(
                    label: 'Average day',
                    value: formatMoney(rhythm.averagePerDay, symbol: symbol),
                  ),
                  _Figure(
                    label: 'Biggest day',
                    value: rhythm.biggestDay == null
                        ? '—'
                        : formatMoney(
                            rhythm.biggestDay!.expenseMinor,
                            symbol: symbol,
                          ),
                    hint: rhythm.biggestDay == null
                        ? null
                        : formatDateLabel(rhythm.biggestDay!.day),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Hairline(indent: 20),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.row,
    required this.share,
    required this.symbol,
  });

  final CategorySpend row;
  final double share;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: <Widget>[
          CategoryTile(category: row.category, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        row.category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink(context),
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(row.amountMinor, symbol: symbol),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: AppColors.line(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      row.category.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.gap, required this.days});

  final MealGap gap;
  final int days;

  @override
  Widget build(BuildContext context) {
    final bool clean = gap.missedDays == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 82,
            child: Text(
              gap.slot.label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink(context),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: clean ? 1 : (gap.loggedDays / (days == 0 ? 1 : days)),
                minHeight: 5,
                backgroundColor: AppColors.line(context),
                valueColor: AlwaysStoppedAnimation<Color>(
                  clean ? Palette.taka : Palette.warning,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: Text(
              clean
                  ? 'every day'
                  : '${gap.missedDays} ${gap.missedDays == 1 ? 'day' : 'days'} unlogged',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11.5, color: AppColors.muted(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure {
  const _Figure({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;
}

class _FigureRow extends StatelessWidget {
  const _FigureRow({required this.figures});

  final List<_Figure> figures;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final _Figure figure in figures)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    figure.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.muted(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      figure.value,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink(context),
                      ),
                    ),
                  ),
                  if (figure.hint != null)
                    Text(
                      figure.hint!,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted(context),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
      ),
    );
  }
}
