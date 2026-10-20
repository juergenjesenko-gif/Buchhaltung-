/// Vorlagen für Buchungsregeln aus den Hilfeartikeln (FA-20.6): „Regel
/// anlegen“ füllt das Formular vor, die Nutzerin passt nur Zahlen an.
library;

import '../domain/booking_rule.dart';
import '../domain/receipt.dart';

enum BookingRuleTemplate {
  /// Privat-PKW teilweise betrieblich (Fahrtenbuch).
  car('Privat-PKW teilweise betrieblich'),

  /// Büro bzw. Arbeitszimmer in der eigenen Wohnung (Fläche).
  homeOffice('Büro in der eigenen Wohnung');

  const BookingRuleTemplate(this.title);
  final String title;

  /// Kategorie der Startliste, auf die die Vorlage zielt.
  String get categoryName => switch (this) {
    car => 'Kfz-Kosten',
    homeOffice => 'Miete & Betriebskosten',
  };

  /// Vorbefüllte Regel; [categories] liefert die ID der Startkategorie.
  BookingRule build(List<ExpenseCategory> categories, DateTime today) {
    final id = categories
        .where((c) => c.name == categoryName)
        .map((c) => c.id)
        .whereType<int>()
        .firstOrNull;
    final from = DateTime(today.year, 1, 1);
    return switch (this) {
      car => BookingRule(
        name: 'PKW',
        type: BookingRuleType.businessShare,
        categoryIds: {if (id != null) id},
        businessPermille: 300,
        basis: BookingRuleBasis.logbook,
        basisPartMilli: 3000 * 1000,
        basisTotalMilli: 10000 * 1000,
        validFrom: from,
        comment:
            'Privat-PKW, betriebliche Fahrten laut Fahrtenbuch. Zahlen '
            'bitte aus dem Fahrtenbuch übernehmen.',
      ),
      homeOffice => BookingRule(
        name: 'Büro',
        type: BookingRuleType.businessShare,
        categoryIds: {if (id != null) id},
        businessPermille: 150,
        basis: BookingRuleBasis.area,
        basisPartMilli: 12 * 1000,
        basisTotalMilli: 80 * 1000,
        validFrom: from,
        comment:
            'Abgeschlossener Raum in der Wohnung, ausschließlich betrieblich '
            'genutzt. Grundriss mit markiertem Büro anhängen.',
      ),
    };
  }
}

/// Vorlage zu einem Hilfeartikel (Überschrift im Handbuch = [title]).
BookingRuleTemplate? templateForHelpTitle(String title) {
  for (final t in BookingRuleTemplate.values) {
    if (title.trim().startsWith(t.title)) return t;
  }
  return null;
}
