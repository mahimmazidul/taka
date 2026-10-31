import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/motion.dart';

/// Custom numeric keypad: no system keyboard pop-up over the form, bigger
/// targets for thumbs, and an exact decimal key.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onDecimal,
    this.rows = 4,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onDecimal;
  final int rows;

  @override
  Widget build(BuildContext context) {
    const List<List<String>> keys = <List<String>>[
      <String>['1', '2', '3'],
      <String>['4', '5', '6'],
      <String>['7', '8', '9'],
      <String>['.', '0', '⌫'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final List<String> row in keys)
          Row(
            children: <Widget>[
              for (final String key in row)
                Expanded(
                  child: _Key(
                    label: key,
                    onTap: () {
                      if (key == '⌫') {
                        onBackspace();
                      } else if (key == '.') {
                        onDecimal?.call();
                      } else {
                        onDigit(key);
                      }
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isBackspace = label == '⌫';

    return Pressable(
      onTap: onTap,
      scale: 0.92,
      child: SizedBox(
        height: 58,
        child: Center(
          child: isBackspace
              ? Icon(
                  Icons.backspace_outlined,
                  size: 19,
                  color: AppColors.muted(context),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink(context),
                  ),
                ),
        ),
      ),
    );
  }
}
