import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import 'mail_server.dart';

/// Gefundene Server für eine Adresse.
typedef MailServers = ({MailServer? imap, MailServer? smtp, String source});

/// Lädt eine Adresse per HTTPS; `null` bei Fehler. Tests setzen einen Ersatz.
typedef AutoconfigFetch = Future<String?> Function(Uri uri);

/// Server automatisch finden (FA-17.9), in dieser Reihenfolge:
///
/// 1. Eingebaute Angaben für Gmail und iCloud (ohne Netz).
/// 2. Mozilla-ISPDB `https://autoconfig.thunderbird.net/v1.1/<domain>`.
/// 3. `https://autoconfig.<domain>/mail/config-v1.1.xml`.
/// 4. `https://<domain>/.well-known/autoconfig/mail/config-v1.1.xml`.
///
/// Übertragen wird nur die **Domain** (Teil nach dem @), nie die ganze
/// Adresse oder ein Kennwort. Nur Einträge mit SSL/TLS oder STARTTLS zählen.
/// Findet sich nichts, gibt die Oberfläche die Felder zum Ausfüllen frei.
class MailAutoconfig {
  MailAutoconfig({AutoconfigFetch? fetch}) : _fetch = fetch ?? httpsGet;

  final AutoconfigFetch _fetch;

  static const ispdb = 'https://autoconfig.thunderbird.net/v1.1/';

  /// Bekannte Anbieter mit App-Passwort (Anleitung in der Oberfläche).
  static MailServers? builtIn(String address) {
    final domain = mailDomain(address);
    final user = address.trim();
    switch (domain) {
      case 'gmail.com':
      case 'googlemail.com':
        return (
          imap: MailServer(
            host: 'imap.gmail.com',
            port: 993,
            security: MailSecurity.tls,
            user: user,
          ),
          smtp: MailServer(
            host: 'smtp.gmail.com',
            port: 465,
            security: MailSecurity.tls,
            user: user,
          ),
          source: 'Gmail',
        );
      case 'icloud.com':
      case 'me.com':
      case 'mac.com':
        return (
          imap: MailServer(
            host: 'imap.mail.me.com',
            port: 993,
            security: MailSecurity.tls,
            // Apple: IMAP-Benutzer ist der Teil vor dem @.
            user: user.split('@').first,
          ),
          smtp: MailServer(
            host: 'smtp.mail.me.com',
            port: 587,
            security: MailSecurity.starttls,
            user: user,
          ),
          source: 'iCloud',
        );
    }
    return null;
  }

  /// Anbieter, für den die App eine App-Passwort-Anleitung zeigt.
  static MailProvider providerOf(String address) =>
      switch (mailDomain(address)) {
        'gmail.com' || 'googlemail.com' => MailProvider.gmail,
        'icloud.com' || 'me.com' || 'mac.com' => MailProvider.icloud,
        _ => MailProvider.other,
      };

  Future<MailServers?> lookup(String address) async {
    if (!isMailAddress(address)) return null;
    final known = builtIn(address);
    if (known != null) return known;
    final domain = mailDomain(address);
    final candidates = [
      (Uri.parse('$ispdb$domain'), 'Thunderbird-Verzeichnis'),
      (
        Uri.parse('https://autoconfig.$domain/mail/config-v1.1.xml'),
        'autoconfig.$domain',
      ),
      (
        Uri.parse(
          'https://$domain/.well-known/autoconfig/mail/config-v1.1.xml',
        ),
        domain,
      ),
    ];
    for (final (uri, label) in candidates) {
      final xml = await _fetch(uri);
      if (xml == null) continue;
      final found = parse(xml, address, source: label);
      if (found != null) return found;
    }
    return null;
  }

  /// Liest eine Thunderbird-Autoconfig-Datei (`clientConfig` 1.1).
  static MailServers? parse(String xml, String address, {String source = ''}) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xml);
    } on XmlException {
      return null;
    }
    MailServer? pick(String element, String type) {
      for (final s in doc.findAllElements(element)) {
        if (s.getAttribute('type') != type) continue;
        String text(String name) => s.getElement(name)?.innerText.trim() ?? '';
        final socket = text('socketType').toUpperCase();
        final MailSecurity security;
        if (socket == 'SSL' || socket == 'TLS') {
          security = MailSecurity.tls;
        } else if (socket == 'STARTTLS') {
          security = MailSecurity.starttls;
        } else {
          continue; // unverschlüsselt: nie
        }
        final port = int.tryParse(text('port'));
        final host = text('hostname');
        if (port == null || host.isEmpty) continue;
        return MailServer(
          host: host,
          port: port,
          security: security,
          user: _user(text('username'), address),
        );
      }
      return null;
    }

    final imap = pick('incomingServer', 'imap');
    final smtp = pick('outgoingServer', 'smtp');
    if (imap == null && smtp == null) return null;
    return (imap: imap, smtp: smtp, source: source);
  }

  static String _user(String template, String address) {
    final a = address.trim();
    final local = a.split('@').first;
    final t = template.isEmpty ? '%EMAILADDRESS%' : template;
    return t
        .replaceAll('%EMAILADDRESS%', a)
        .replaceAll('%EMAILLOCALPART%', local)
        .replaceAll('%EMAILDOMAIN%', mailDomain(a));
  }

  /// HTTPS-Abruf mit kurzer Zeitgrenze; Fehler ergeben `null`.
  static Future<String?> httpsGet(Uri uri) async {
    if (uri.scheme != 'https') return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return await res.transform(utf8.decoder).join();
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// Anbieter mit eigener App-Passwort-Anleitung.
enum MailProvider {
  gmail,
  icloud,
  other;

  /// Direkter Link zur Seite, auf der das App-Passwort entsteht.
  String? get appPasswordUrl => switch (this) {
    gmail => 'https://myaccount.google.com/apppasswords',
    icloud => 'https://account.apple.com',
    other => null,
  };

  /// Nummerierte Schritte (Leitprinzip: kurze, nummerierte Schritte).
  List<String> get appPasswordSteps => switch (this) {
    gmail => const [
      'Unten „App-Passwort erstellen“ tippen – die Google-Seite öffnet sich.',
      'Mit deinem Google-Konto anmelden (Bestätigung in zwei Schritten muss '
          'eingeschaltet sein).',
      'Als Namen „JeNi bucht“ eingeben und „Erstellen“ tippen.',
      'Das 16-stellige Passwort kopieren, hierher zurückkehren und ins Feld '
          '„App-Passwort“ einfügen.',
    ],
    icloud => const [
      'Unten „App-Passwort erstellen“ tippen – account.apple.com öffnet sich.',
      'Mit deiner Apple-ID anmelden.',
      '„Anmeldung und Sicherheit“ → „App-spezifische Passwörter“ → „+“, als '
          'Namen „JeNi bucht“.',
      'Das Passwort (xxxx-xxxx-xxxx-xxxx) kopieren, hierher zurückkehren und '
          'ins Feld „App-Passwort“ einfügen.',
    ],
    other => const [
      'Bei vielen Anbietern geht das normale Kennwort.',
      'Ist die Anmeldung in zwei Schritten eingeschaltet, im Konto des '
          'Anbieters ein App-Passwort erstellen und hier eintragen.',
    ],
  };
}
