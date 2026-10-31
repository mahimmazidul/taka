import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/motion.dart';

class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Two-or-three way switch with a sliding pill. Used for expense/income and
/// for the udhar lent/borrowed tabs.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.height = 42,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final int index = options.indexWhere(
      (SegmentOption<T> o) => o.value == value,
    );
    final int selected = index < 0 ? 0 : index;
    const Duration slide = Duration(milliseconds: 220);

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: AppColors.line(context)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double slot = constraints.maxWidth / options.length;
          return Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: slide,
                curve: Curves.easeOutCubic,
                left: selected * slot,
                top: 0,
                bottom: 0,
                width: slot,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF12A98C), Palette.takaDeep],
                    ),
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  for (final SegmentOption<T> option in options)
                    Expanded(
                      child: Pressable(
                        onTap: () => onChanged(option.value),
                        scale: 0.95,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: slide,
                            style: TextStyle(
                              fontFamily: kFontFamily,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: option.value == value
                                  ? Colors.white
                                  : AppColors.muted(context),
                            ),
                            child: Text(option.label),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Small selectable chip used for filters and the category picker.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.tint,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final Color accent = tint ?? Palette.taka;

    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(
                  alpha: AppColors.isDark(context) ? 0.22 : 0.13,
                )
              : AppColors.surface(context),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.55)
                : AppColors.line(context),
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 15,
                color: selected ? accent : AppColors.muted(context),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? accent : AppColors.muted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
