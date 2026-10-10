/// Offline-Formatprüfung von UID-Nummern, bevor eine Abfrage das Gerät
/// verlässt. Für Österreich und Deutschland mit Prüfziffer, für die übrigen
/// EU-Länder nur Länderkennung und grobe Länge.
class VatIdFormat {
  const VatIdFormat._();

  /// Entfernt Leerzeichen, Punkte und Bindestriche und schreibt groß.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');

  /// Ländercode laut VIES (Griechenland: `EL`).
  static String? countryCode(String normalized) {
    if (normalized.length < 4) return null;
    final code = normalized.substring(0, 2);
    return _euCodes.contains(code) ? code : null;
  }

  /// Nummer ohne Ländercode.
  static String number(String normalized) => normalized.substring(2);

  /// `null` bei gültigem Format, sonst eine Fehlermeldung für das Formular.
  static String? check(String input) {
    final value = normalize(input);
    if (value.isEmpty) return null;
    final code = countryCode(value);
    if (code == null) {
      return 'Die Nummer beginnt nicht mit einem EU-Ländercode (z. B. ATU, DE)';
    }
    final rest = number(value);
    switch (code) {
      case 'AT':
        if (!RegExp(r'^U\d{8}$').hasMatch(rest)) {
          return 'Österreichische UID: ATU und 8 Ziffern';
        }
        if (!_austrianCheckDigitOk(rest.substring(1))) {
          return 'Die Prüfziffer der UID stimmt nicht – bitte Tippfehler prüfen';
        }
      case 'DE':
        if (!RegExp(r'^\d{9}$').hasMatch(rest)) {
          return 'Deutsche USt-IdNr.: DE und 9 Ziffern';
        }
        if (!_germanCheckDigitOk(rest)) {
          return 'Die Prüfziffer der USt-IdNr. stimmt nicht – bitte Tippfehler prüfen';
        }
      default:
        if (!RegExp(r'^[0-9A-Z+*]{2,12}$').hasMatch(rest)) {
          return 'Ungültiges Format der UID';
        }
    }
    return null;
  }

  /// Österreich: Ziffern 1–7 abwechselnd mit 1 und 2 gewichtet, bei Produkten
  /// über 9 die Quersumme; Prüfziffer = (96 − Summe) mod 10.
  static bool _austrianCheckDigitOk(String digits) {
    var sum = 0;
    for (var i = 0; i < 7; i++) {
      var product = int.parse(digits[i]) * (i.isOdd ? 2 : 1);
      if (product > 9) product = product ~/ 10 + product % 10;
      sum += product;
    }
    return (96 - sum) % 10 == int.parse(digits[7]);
  }

  /// Deutschland: ISO 7064 MOD 11,10 über die ersten 8 Ziffern.
  static bool _germanCheckDigitOk(String digits) {
    var product = 10;
    for (var i = 0; i < 8; i++) {
      var sum = (int.parse(digits[i]) + product) % 10;
      if (sum == 0) sum = 10;
      product = (2 * sum) % 11;
    }
    final check = (11 - product) % 10;
    return check == int.parse(digits[8]);
  }

  static const _euCodes = {
    'AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'EL', 'ES', 'FI', 'FR', //
    'HR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', //
    'SE', 'SI', 'SK', 'XI',
  };
}
