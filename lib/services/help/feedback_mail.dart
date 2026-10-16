import 'support_mail.dart';

/// Art eines Wunsches (FA-11.6). Reihenfolge = Reihenfolge der Chips.
enum FeedbackKind {
  feature('Neue Funktion'),
  improvement('Verbesserung'),
  bug('Fehler melden');

  const FeedbackKind(this.label);
  final String label;
}

/// Technische Angaben, die die Nutzerin mitsenden kann (FA-11.6). Bewusst
/// nur diese fünf: keine Geschäftsdaten, keine Belege, keine Kennungen.
class FeedbackContext {
  const FeedbackContext({
    this.appVersion,
    this.device,
    required this.country,
    required this.tier,
  });

  final String? appVersion;

  /// Betriebssystemversion und Gerätemodell.
  final String? device;

  /// Länderprofil, „AT“ oder „DE“.
  final String country;

  /// Abo-Stufe, z. B. „Pro“.
  final String tier;
}

/// Erweiterungswunsch per Mail-App (FA-11.6): Die App baut nur Betreff und
/// Text; gesendet wird ausschließlich aus der Mail-App der Nutzerin.
class FeedbackMail {
  const FeedbackMail({
    required this.kind,
    required this.title,
    required this.description,
    this.context,
  });

  final FeedbackKind kind;
  final String title;
  final String description;

  /// `null`, wenn „App-Version und Gerät mitsenden“ aus ist.
  final FeedbackContext? context;

  /// Höchstzahl Wörter aus der Beschreibung, wenn kein Titel da ist.
  static const subjectWords = 6;

  String get subject {
    var topic = title.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (topic.isEmpty) {
      final words = description.trim().split(RegExp(r'\s+'));
      topic = words.take(subjectWords).join(' ');
      if (words.length > subjectWords) topic = '$topic …';
    }
    return '[JeNi bucht] ${kind.label}: $topic';
  }

  String get body {
    final b = StringBuffer()
      ..writeln('Art: ${kind.label}')
      ..writeln()
      ..writeln(description.trim());
    final c = context;
    if (c != null) {
      b
        ..writeln()
        ..writeln('--')
        ..writeln('App-Version: ${c.appVersion ?? '?'}')
        ..writeln('Gerät: ${c.device ?? '?'}')
        ..writeln('Länderprofil: ${c.country}')
        ..writeln('Abo: ${c.tier}');
    }
    return b.toString();
  }

  /// `mailto:` mit Betreff und Text; Leerzeichen als %20 (RFC 6068).
  Uri get uri => Uri(
    scheme: 'mailto',
    path: supportAddress,
    query:
        'subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}',
  );

  /// Text für die Zwischenablage, wenn keine Mail-App da ist.
  String get clipboardText => 'An: $supportAddress\nBetreff: $subject\n\n$body';
}
