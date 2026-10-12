/// Texte, die die Nutzerin bei der ersten Einrichtung bestätigt (Lastenheft
/// L-17.1 bis L-17.4, L-17.12). Jede wesentliche Änderung bekommt eine neue
/// [version]; die App holt die Bestätigung dann erneut ein.
///
/// Die Fassungen sind **Entwürfe**: Nutzungsbedingungen und
/// Datenschutzerklärung erstellt bzw. prüft vor dem Release eine Anwältin
/// (L-17.11, Spezifikation Abschnitt 14, P-L1).
class LegalText {
  const LegalText({
    required this.kind,
    required this.version,
    required this.title,
    required this.summary,
    required this.confirmation,
  });

  final String kind;
  final String version;
  final String title;
  final String summary;
  final String confirmation;

  /// L-17.1/L-17.2: eigenständig, von den Nutzungsbedingungen getrennt.
  static const disclaimer = LegalText(
    kind: 'disclaimer',
    version: '2026-10-12',
    title: 'Keine Steuerberatung',
    summary:
        'Diese App ist ein Werkzeug für dein eigenes Büro. Sie rechnet und '
        'bereitet vor, prüft aber nichts steuerrechtlich und ersetzt keine '
        'Steuerberatung. Für deine Buchhaltung und deine Steuererklärungen '
        'bist du selbst verantwortlich; lass sie von einer Steuerberatung '
        'prüfen.',
    confirmation:
        'Ich habe verstanden, dass die App Informationen bereitstellt, sie '
        'aber nicht steuerrechtlich prüft, und dass die Prüfung durch eine '
        'Steuerberatung erforderlich bleibt.',
  );

  static const terms = LegalText(
    kind: 'terms',
    version: '2026-10-12-entwurf',
    title: 'Nutzungsbedingungen und Datenschutz',
    summary:
        'Deine Daten bleiben auf deinem Gerät; der Anbieter erhält sie nicht. '
        'Daten verlassen das Gerät nur, wenn du teilst, eine Sicherung '
        'anlegst oder eine UID-Nummer prüfen lässt. Nutzungsbedingungen und '
        'Datenschutzerklärung im Volltext findest du auf der Produktseite und '
        'in den Einstellungen.',
    confirmation:
        'Ich akzeptiere die Nutzungsbedingungen und habe die '
        'Datenschutzerklärung zur Kenntnis genommen.',
  );

  static const all = [disclaimer, terms];
}
