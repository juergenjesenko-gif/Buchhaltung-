import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../domain/booking_rule.dart';
import '../../services/booking_rule_split.dart';
import 'booking_rules_screen.dart';

/// Hinweis an der Buchung (FA-20.4): „Regel: PKW 30 % betrieblich“, Tippen
/// öffnet die Regel; der Schalter nimmt die gespeicherte Buchung aus.
class BookingRuleStrip extends StatefulWidget {
  const BookingRuleStrip({super.key, required this.facts, this.receiptId});

  final BookingFacts facts;

  /// `null` bei neuen Buchungen: Ausnehmen geht erst nach dem Speichern.
  final int? receiptId;

  @override
  State<BookingRuleStrip> createState() => _BookingRuleStripState();
}

class _BookingRuleStripState extends State<BookingRuleStrip> {
  List<BookingRule> _rules = const [];
  Set<int> _excluded = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = AppScope.read(context).repositories.bookingRules;
    final rules = await repo.all();
    final id = widget.receiptId;
    final excluded = id == null ? <int>{} : await repo.exclusionsFor(id);
    if (mounted) {
      setState(() {
        _rules = rules;
        _excluded = excluded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rule = matchingRule(_rules, widget.facts);
    if (rule == null) return const SizedBox.shrink();
    final excluded = _excluded.contains(rule.id);
    final id = widget.receiptId;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          ListTile(
            key: const Key('booking-rule-strip'),
            minTileHeight: 56,
            leading: const Icon(Icons.rule),
            title: Text('Regel: ${rule.shortLabel}'),
            subtitle: Text(
              excluded
                  ? 'Diese Buchung ist ausgenommen und zählt voll.'
                  : 'Privatanteil ${formatPermille(rule.privatePermille)} '
                        'zählt nicht als Betriebsausgabe.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await openBookingRule(context, rule: rule);
              await _load();
            },
          ),
          if (id != null)
            SwitchListTile(
              key: const Key('booking-rule-exclude'),
              title: const Text('Diese Buchung ausnehmen'),
              value: excluded,
              onChanged: (on) async {
                await AppScope.read(
                  context,
                ).repositories.bookingRules.setExcluded(rule.id!, id, on);
                await _load();
              },
            ),
        ],
      ),
    );
  }
}
