import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/motion.dart';

/// The number pad, with Save parked in the same block.
///
/// Sizes come from the space actually available, so the pad shrinks on a small
/// phone and in landscape instead of overflowing, and the Save pill stays under
/// the thumb's resting position.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onDecimal,
    required this.onSave,
    required this.saveLabel,
    this.cellHeight = 58,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onDecimal;
  final VoidCallback onSave;
  final String saveLabel;
  final double cellHeight;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final double cell = cellHeight.clamp(38.0, 66.0);
    final double saveHeight = (cell * 0.86).clamp(42.0, 56.0);

    // Save sits in the bottom row of the same block — under the thumb, never a
    // reach back up the screen. Full width so it is a big, obvious target.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final List<String> row in const <List<String>>[
          <String>['1', '2', '3'],
          <String>['4', '5', '6'],
          <String>['7', '8', '9'],
        ])
          Row(
            children: <Widget>[
              for (final String digit in row)
                _Key(label: digit, height: cell, onTap: () => onDigit(digit)),
            ],
          ),
        Row(
          children: <Widget>[
            _Key(label: '.', height: cell, onTap: onDecimal),
            _Key(label: '0', height: cell, onTap: () => onDigit('0')),
            _Key(
              icon: Icons.backspace_outlined,
              height: cell,
              onTap: onBackspace,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Pressable(
          onTap: enabled ? onSave : null,
          scale: 0.98,
          child: Container(
            height: saveHeight,
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
              borderRadius: BorderRadius.circular(saveHeight * 0.32),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.check_rounded,
                  size: saveHeight * 0.44,
                  color: Colors.white,
                ),
                const SizedBox(width: 7),
                Text(
                  saveLabel.toUpperCase(),
                  style: TextStyle(
                    fontFamily: kFontFamily,
                    fontSize: (saveHeight * 0.30).clamp(11.0, 14.5),
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

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    required this.height,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: SizedBox(
          height: height,
          child: Center(
            child: icon != null
                ? Icon(icon, size: height * 0.34, color: AppColors.ink(context))
                : Text(
                    label!,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: height * 0.46,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink(context),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
