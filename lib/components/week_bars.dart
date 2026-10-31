import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/period_totals.dart';
import '../utils/date_helpers.dart';
import '../core/clock.dart';

/// Seven bare bars. Each grows into place once on mount — one tween per bar,
/// no painting tricks, so it costs nothing on a low-end phone.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.days, this.height = 104});

  final List<DailyTotal> days;
  final double height;

  @override
  Widget build(BuildContext context) {
    final int maxMinor = days.fold<int>(
      0,
      (int best, DailyTotal day) =>
          day.expenseMinor > best ? day.expenseMinor : best,
    );
    final DateTime today = AppClock.now();

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < days.length; i++)
            Expanded(
              child: _Bar(
                day: days[i],
                ratio: maxMinor == 0 ? 0 : days[i].expenseMinor / maxMinor,
                isToday: isSameDay(days[i].day, today),
                delayMs: i * 45,
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.day,
    required this.ratio,
    required this.isToday,
    required this.delayMs,
  });

  final DailyTotal day;
  final double ratio;
  final bool isToday;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final double target = ratio.clamp(0.02, 1).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: target),
              duration: Duration(milliseconds: 420 + delayMs),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double value, Widget? _) {
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: value,
                    widthFactor: 0.66,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isToday
                              ? <Color>[
                                  Palette.taka,
                                  Palette.taka.withValues(alpha: 0.62),
                                ]
                              : <Color>[
                                  AppColors.muted(context)
                                      .withValues(alpha: 0.30),
                                  AppColors.muted(context)
                                      .withValues(alpha: 0.14),
                                ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            weekdayShort(day.day).substring(0, 1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? Palette.taka : AppColors.muted(context),
            ),
          ),
        ],
      ),
    );
  }
}
