/// Tolerante Formatprüfung für E-Mail-Adresse und Telefonnummer.
///
/// Entscheidung der Auftraggeberin 2026-10-15 (Lastenheft O-30): nur
/// Formatprüfung, keine Verifizierung. Leere Felder sind erlaubt; die
/// Nutzerin kann die Angaben jederzeit ändern.
class ContactFormat {
  ContactFormat._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s.]{2,}$');

  /// `null`, wenn leer oder plausibel; sonst die Fehlermeldung.
  static String? checkEmail(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    if (!_email.hasMatch(v)) {
      return 'Bitte eine E-Mail-Adresse wie name@beispiel.at eingeben';
    }
    return null;
  }

  static final _phoneChars = RegExp(r'^\+?[0-9 /()\-]+$');

  /// Erlaubt Ziffern, ein führendes +, Leerzeichen sowie / ( ) -;
  /// 6 bis 20 Ziffern.
  static String? checkPhone(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (!_phoneChars.hasMatch(v) || digits < 6 || digits > 20) {
      return 'Bitte eine Telefonnummer mit 6 bis 20 Ziffern eingeben, '
          'z. B. +43 660 1234567';
    }
    return null;
  }
}
