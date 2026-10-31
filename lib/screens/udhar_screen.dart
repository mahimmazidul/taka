import 'package:flutter/material.dart';

import '../components/app_sheet.dart';
import '../components/category_tile.dart';
import '../components/empty_state.dart';
import '../components/primary_button.dart';
import '../components/segmented.dart';
import '../core/app_theme.dart';
import '../core/motion.dart';
import '../models/udhar_entry.dart';
import '../store/app_state.dart';
import '../store/udhar_actions.dart';
import '../utils/date_helpers.dart';
import '../utils/format_currency.dart';

/// Lend / borrow tracker. Marking something returned is one tap; long-press
/// deletes it.
class UdharScreen extends StatefulWidget {
  const UdharScreen({super.key});

  @override
  State<UdharScreen> createState() => _UdharScreenState();
}

class _UdharScreenState extends State<UdharScreen> {
  UdharType _type = UdharType.lent;
  bool _showReturned = false;

  Future<void> _addSheet() async {
    final TextEditingController person = TextEditingController();
    final TextEditingController amount = TextEditingController();
    final TextEditingController note = TextEditingController();
    final UdharType type = _type;

    await showAppSheet<void>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder:
            (BuildContext context, void Function(void Function()) setSheet) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SheetTitle(
                      title: type == UdharType.lent
                          ? 'You lent money'
                          : 'You borrowed money',
                      subtitle: 'Who is it with?',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: person,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Name',
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Amount',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 6),
                          child: Text(
                            AppState.instance.currencySymbol,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.muted(context),
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: note,
                      decoration: const InputDecoration(
                        hintText: 'Note (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Save',
                      icon: Icons.check_rounded,
                      onPressed: () async {
                        final int? minor = parseAmountToMinor(amount.text);
                        if (minor == null || person.text.trim().isEmpty) {
                          setSheet(() {});
                          return;
                        }
                        await AppState.instance.addUdhar(
                          type: type,
                          person: person.text,
                          amountMinor: minor,
                          note: note.text,
                          occurredAt: DateTime.now(),
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              );
            },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (BuildContext context, Widget? _) {
        final AppState state = AppState.instance;
        final String symbol = state.currencySymbol;
        final List<UdharEntry> all = state.udharFor(_type);
        final List<UdharEntry> open = all
            .where((UdharEntry e) => !e.returned)
            .toList();
        final List<UdharEntry> settled = all
            .where((UdharEntry e) => e.returned)
            .toList();
        final int openTotal = open.fold<int>(
          0,
          (int sum, UdharEntry e) => sum + e.amountMinor,
        );

        return SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Udhar',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: AppColors.ink(context),
                      ),
                    ),
                    Text(
                      _type == UdharType.lent
                          ? '${formatMoney(openTotal, symbol: symbol)} to receive'
                          : '${formatMoney(openTotal, symbol: symbol)} to pay',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Segmented<UdharType>(
                      value: _type,
                      onChanged: (UdharType value) =>
                          setState(() => _type = value),
                      options: const <SegmentOption<UdharType>>[
                        SegmentOption<UdharType>(
                          value: UdharType.lent,
                          label: 'I lent',
                        ),
                        SegmentOption<UdharType>(
                          value: UdharType.borrowed,
                          label: 'I borrowed',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: all.isEmpty
                    ? EmptyState(
                        icon: Icons.handshake_outlined,
                        title: 'No udhar recorded',
                        message: _type == UdharType.lent
                            ? 'Money you give someone shows up here until it comes back.'
                            : 'Money you take from someone shows up here until you pay it back.',
                        actionLabel: 'Add udhar',
                        onAction: _addSheet,
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 110),
                        children: <Widget>[
                          for (final UdharEntry entry in open) ...<Widget>[
                            _UdharRow(entry: entry, symbol: symbol),
                            const SizedBox(height: 2),
                          ],
                          if (settled.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                              child: Pressable(
                                onTap: () => setState(
                                  () => _showReturned = !_showReturned,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Text(
                                      'SETTLED (${settled.length})',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        letterSpacing: 1.1,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.muted(context),
                                      ),
                                    ),
                                    Icon(
                                      _showReturned
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      size: 17,
                                      color: AppColors.muted(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_showReturned)
                            for (final UdharEntry entry in settled)
                              _UdharRow(entry: entry, symbol: symbol),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                child: PrimaryButton(
                  label: _type == UdharType.lent
                      ? 'Add lent money'
                      : 'Add borrowed money',
                  icon: Icons.add_rounded,
                  onPressed: _addSheet,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UdharRow extends StatelessWidget {
  const _UdharRow({required this.entry, required this.symbol});

  final UdharEntry entry;
  final String symbol;

  Color _accent(BuildContext context) => entry.type == UdharType.lent
      ? AppColors.income(context)
      : Palette.warning;

  @override
  Widget build(BuildContext context) {
    final Color accent = _accent(context);

    return Pressable(
      onTap: () => AppState.instance.setUdharReturned(
        entry.id,
        returned: !entry.returned,
      ),
      onLongPress: () async {
        final bool? ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Delete record?'),
            content: Text(
              '${entry.person} · ${formatMoney(entry.amountMinor, symbol: symbol)}',
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
        if (ok == true) await AppState.instance.deleteUdhar(entry.id);
      },
      child: Opacity(
        opacity: entry.returned ? 0.55 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            children: <Widget>[
              IconTile(
                icon: entry.type == UdharType.lent
                    ? Icons.north_east_rounded
                    : Icons.south_west_rounded,
                color: accent,
                size: 40,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.person,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink(context),
                      ),
                    ),
                    Text(
                      <String>[
                        if (entry.note.isNotEmpty) entry.note,
                        formatDateLabel(entry.occurredAt),
                        if (entry.returned) 'settled',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatMoney(entry.amountMinor, symbol: symbol),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: entry.returned ? AppColors.muted(context) : accent,
                    ),
                  ),
                  Text(
                    entry.returned ? 'returned' : 'tap to settle',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
