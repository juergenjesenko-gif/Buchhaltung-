import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../domain/country.dart';
import '../../domain/money.dart';
import '../../services/receipt_vat_split.dart';
import '../../services/vat_calculator.dart';
import '../../widgets/common.dart';
import '../../domain/currency.dart';

/// Ein Teil der Aufteilung im Formular: Satz, Bruttobetrag als Text und ob
/// der Betrag noch der automatische Rest ist.
class VatPartField {
  VatPartField(this.permille, String text, {this.auto = false})
    : controller = TextEditingController(text: text);

  int permille;
  final TextEditingController controller;

  /// Der letzte Teil übernimmt den Rest, bis die Nutzerin ihn selbst ändert.
  bool auto;

  Money? get gross => Money.tryParse(controller.text);
}

/// Zustand der Aufteilung nach Steuersätzen (L-2.27). Hält nur Eingaben;
/// gerechnet wird in [ReceiptVatSplit].
class VatSplitController {
  final List<VatPartField> parts = [];

  /// Aufteilung aktiv: mindestens zwei Teile.
  bool get active => parts.length > 1;

  /// Beginnt die Aufteilung: der bisherige Satz trägt zunächst den ganzen
  /// Betrag, der neue Teil den Rest (0). Tippt man den ersten Teil ein,
  /// rechnet sich der zweite selbst.
  void start({
    required Money? total,
    required int firstPermille,
    required int secondPermille,
  }) {
    clear();
    parts.add(
      VatPartField(firstPermille, total == null ? '' : Fmt.amount(total)),
    );
    parts.add(VatPartField(secondPermille, '', auto: true));
    recalc(total);
  }

  /// Weiterer Teil am Ende; er übernimmt den Rest.
  void add(int permille, Money? total) {
    for (final part in parts) {
      part.auto = false;
    }
    parts.add(VatPartField(permille, '', auto: true));
    recalc(total);
  }

  /// Entfernt einen Teil. Bleibt nur einer übrig, endet die Aufteilung; der
  /// Rückgabewert ist dann dessen Satz.
  int? remove(int index, Money? total) {
    parts.removeAt(index).controller.dispose();
    if (parts.length == 1) {
      final permille = parts.single.permille;
      clear();
      return permille;
    }
    parts.last.auto = true;
    recalc(total);
    return null;
  }

  /// Rest dem letzten Teil vorschlagen, solange er automatisch ist.
  void recalc(Money? total) {
    if (parts.length < 2 || !parts.last.auto || total == null) return;
    final others = parts
        .take(parts.length - 1)
        .map((p) => p.gross ?? const Money.zero());
    final rest = ReceiptVatSplit.remainder(total, others);
    parts.last.controller.text = Fmt.amount(rest);
  }

  /// Nach einer Eingabe im Teil [index].
  void edited(int index, Money? total) {
    if (index == parts.length - 1) {
      parts.last.auto = false;
    } else {
      recalc(total);
    }
  }

  /// Vorbelegung, z. B. aus der Belegerkennung oder einem gespeicherten
  /// Beleg. Der letzte Teil bleibt automatisch, damit eine korrigierte
  /// Gesamtsumme den Rest nachzieht.
  void load(List<VatPart> values) {
    clear();
    for (final value in values) {
      parts.add(VatPartField(value.permille, Fmt.amount(value.gross)));
    }
    if (parts.isNotEmpty) parts.last.auto = true;
  }

  /// Eingegebene Teile; `null`, wenn ein Betrag fehlt oder unlesbar ist.
  List<VatPart>? get values {
    final result = <VatPart>[];
    for (final part in parts) {
      final gross = part.gross;
      if (gross == null || gross.isNegative) return null;
      result.add((permille: part.permille, gross: gross));
    }
    return result;
  }

  /// Fehlertext, wenn die Teile nicht den Belegbetrag ergeben.
  String? check(Money? total) {
    if (!active || total == null) return null;
    final values = this.values;
    if (values == null) return 'Bitte jeden Teilbetrag eingeben.';
    final diff = ReceiptVatSplit.difference(total, values.map((v) => v.gross));
    if (diff.isZero) return null;
    return 'Die Teile ergeben ${Fmt.money(values.map((v) => v.gross).sum)}, '
        'der Beleg ${Fmt.money(total)} '
        '(${diff.isNegative ? 'fehlen' : 'zu viel'} ${Fmt.money(diff.abs)}).';
  }

  void clear() {
    for (final part in parts) {
      part.controller.dispose();
    }
    parts.clear();
  }

  void dispose() => clear();
}

/// Eingabe der Teilbeträge je Steuersatz: je Teil Satz und Bruttobetrag
/// nebeneinander, darunter Netto und Steuer des Teils. Volle Breite, Felder
/// und Knöpfe ≥ 48 dp (DESIGN_SPEC 5a).
class VatSplitEditor extends StatelessWidget {
  const VatSplitEditor({
    super.key,
    required this.controller,
    required this.total,
    required this.tax,
    required this.date,
    required this.onChanged,
    required this.onRemove,
  });

  final VatSplitController controller;
  final Money? total;
  final TaxProfile tax;
  final DateTime date;
  final VoidCallback onChanged;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final error = controller.check(total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < controller.parts.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: DropdownButtonFormField<int>(
                  key: ValueKey(
                    'split-rate-$i-${controller.parts[i].permille}',
                  ),
                  initialValue: controller.parts[i].permille,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'Satz ${i + 1}'),
                  items: [
                    for (final rate in tax.vatRatesOn(
                      date,
                      keep: controller.parts[i].permille,
                    ))
                      DropdownMenuItem(
                        value: rate.permille,
                        child: Text(rate.display),
                      ),
                  ],
                  onChanged: (value) {
                    controller.parts[i].permille = value ?? 0;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: TextFormField(
                  key: ValueKey('split-gross-$i'),
                  controller: controller.parts[i].controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText:
                        i == controller.parts.length - 1 &&
                            controller.parts[i].auto
                        ? 'Rest brutto'
                        : 'Brutto',
                    suffixText: Currency.home.symbol,
                  ),
                  onChanged: (_) {
                    controller.edited(i, total);
                    onChanged();
                  },
                ),
              ),
              IconButton(
                key: ValueKey('split-remove-$i'),
                tooltip: 'Teil entfernen',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => onRemove(i),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(_partInfo(controller.parts[i]), style: muted),
          ),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              error,
              key: const ValueKey('split-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  static String _partInfo(VatPartField part) {
    final gross = part.gross;
    if (gross == null) return 'Betrag eingeben';
    final split = VatCalculator.fromGross(gross, part.permille);
    return 'Netto ${Fmt.money(split.net)} · '
        'USt ${Fmt.vatRate(part.permille)} ${Fmt.money(split.vat)}';
  }
}

/// Knopf „Weiteren Steuersatz hinzufügen“, volle Breite, 48 dp.
class AddVatRateButton extends StatelessWidget {
  const AddVatRateButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('split-add'),
    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    onPressed: onPressed,
    icon: const Icon(Icons.call_split),
    label: const Text('Weiteren Steuersatz hinzufügen'),
  );
}

/// Hinweis unter der Aufteilung, z. B. für Bewirtungsbelege.
class VatSplitNote extends StatelessWidget {
  const VatSplitNote({super.key});

  @override
  Widget build(BuildContext context) => const NoticeBanner(
    icon: Icons.info_outline,
    message:
        'Brutto je Steuersatz eintragen, wie auf dem Beleg ausgewiesen '
        '(z. B. Speisen und Getränke). Der letzte Teil übernimmt den Rest.',
  );
}
