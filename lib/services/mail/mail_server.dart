/// Postfach-Einstellungen für den Mailweg der Mithelfer-Geräte (FA-17.9).
///
/// Nur Server, Port, Benutzer und Art der Verschlüsselung; das Kennwort liegt
/// ausschließlich im sicheren Speicher des jeweiligen Geräts
/// ([MailCredentialStore]) und nie in der Datenbank, einer Sicherung oder
/// einem QR-Code.
library;

/// TLS ist Pflicht (FA-17.9): entweder sofort (IMAPS 993, SMTPS 465) oder
/// über STARTTLS (IMAP 143, Submission 587). Unverschlüsselt gibt es nicht.
enum MailSecurity {
  tls,
  starttls;

  String get label => switch (this) {
    tls => 'SSL/TLS',
    starttls => 'STARTTLS',
  };

  static MailSecurity parse(String? s) => s == 'starttls' ? starttls : tls;
}

/// Ein Server (IMAP zum Lesen auf dem Hauptgerät, SMTP zum Senden auf dem
/// Mithelfer-Gerät).
class MailServer {
  const MailServer({
    required this.host,
    required this.port,
    required this.security,
    required this.user,
  });

  final String host;
  final int port;
  final MailSecurity security;

  /// Anmeldename, meist die ganze Adresse.
  final String user;

  bool get isComplete =>
      host.trim().isNotEmpty &&
      port > 0 &&
      port < 65536 &&
      user.trim().isNotEmpty;

  Map<String, Object?> toJson() => {
    'host': host,
    'port': port,
    'security': security.name,
    'user': user,
  };

  static MailServer fromJson(Map<String, Object?> j) => MailServer(
    host: j['host'] as String? ?? '',
    port: (j['port'] as num?)?.toInt() ?? 0,
    security: MailSecurity.parse(j['security'] as String?),
    user: j['user'] as String? ?? '',
  );

  MailServer copyWith({
    String? host,
    int? port,
    MailSecurity? security,
    String? user,
  }) => MailServer(
    host: host ?? this.host,
    port: port ?? this.port,
    security: security ?? this.security,
    user: user ?? this.user,
  );

  @override
  bool operator ==(Object other) =>
      other is MailServer &&
      other.host == host &&
      other.port == port &&
      other.security == security &&
      other.user == user;

  @override
  int get hashCode => Object.hash(host, port, security, user);

  @override
  String toString() => '$user@$host:$port (${security.label})';
}

/// Fehler beim Mailweg mit verständlicher Meldung für die Oberfläche.
class MailException implements Exception {
  const MailException(this.message, {this.authentication = false});

  final String message;

  /// Anmeldung abgelehnt (Kennwort/App-Passwort falsch).
  final bool authentication;

  @override
  String toString() => message;
}

/// Einfache Formprüfung einer E-Mail-Adresse (wie FA-1.4f).
bool isMailAddress(String s) =>
    RegExp(r'^[^@\s<>"]+@[^@\s<>"]+\.[A-Za-z]{2,}$').hasMatch(s.trim());

/// Domain einer Adresse, klein geschrieben.
String mailDomain(String address) =>
    address.trim().split('@').last.toLowerCase();
