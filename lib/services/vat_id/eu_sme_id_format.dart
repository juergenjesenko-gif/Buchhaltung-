import '../../domain/country.dart';
import 'vat_id_format.dart';

/// Offline-Formatprüfung der EU-KU-Nummer für das EU-Kleinunternehmer-
/// Verfahren (FA-18.10).
///
/// Art 284 Abs 3 MwStSystRL idF RL (EU) 2020/285: Der Mitgliedstaat der
/// Ansässigkeit erteilt eine individuelle Identifikationsnummer mit dem
/// Suffix „EX“. Umsetzung DE § 19a UStG (BZSt, „Kleinunternehmer-
/// Identifikationsnummer“, Aufbau `DE` + 9 Ziffern + `EX`), AT § 6 Abs 1 Z 27
/// UStG 1994 idF AbgÄG 2024 (Finanzamt Österreich, Aufbau `ATU` + 8 Ziffern +
/// `EX`). Die Ziffern entsprechen der Struktur der UID des Heimatstaats, daher
/// dieselbe Prüfziffer. Aufbau in beiden Ländern ungesichert: P-S76.
class EuSmeIdFormat {
  const EuSmeIdFormat._();

  static const suffix = 'EX';

  static String normalize(String input) => VatIdFormat.normalize(input);

  /// Beispiel für das Eingabefeld je Heimatland.
  static String example(Country home) =>
      home == Country.de ? 'DE123456789EX' : 'ATU12345675EX';

  /// `null` bei gültigem Format, sonst eine Fehlermeldung. Leer ist erlaubt
  /// (Nummer noch beantragt).
  static String? check(String input, {required Country home}) {
    final value = normalize(input);
    if (value.isEmpty) return null;
    if (!value.endsWith(suffix)) {
      return 'Die EU-KU-Nummer endet auf EX, z. B. ${example(home)}';
    }
    final base = value.substring(0, value.length - suffix.length);
    if (!base.startsWith(home.code)) {
      return 'Die EU-KU-Nummer vergibt ${home.label}: sie beginnt mit '
          '${home == Country.at ? 'ATU' : 'DE'}';
    }
    final error = VatIdFormat.check(base);
    if (error != null) {
      return home == Country.at
          ? 'Österreichische EU-KU-Nummer: ATU, 8 Ziffern, EX'
          : 'Deutsche EU-KU-Nummer: DE, 9 Ziffern, EX';
    }
    return null;
  }
}
