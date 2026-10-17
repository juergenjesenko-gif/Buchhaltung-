import 'dart:convert';

import 'mail_channel.dart';
import 'mail_server.dart';

/// Senden einer fertigen Nachricht über SMTP-Submission (RFC 6409) mit
/// Anmeldung (AUTH PLAIN, sonst AUTH LOGIN), nur verschlüsselt (FA-17.9).
class SmtpSender {
  SmtpSender(this.server, this.password, {MailConnector? connector})
    : _connect = connector ?? IoMailChannel.connect;

  final MailServer server;
  final String password;
  final MailConnector _connect;

  /// Anmeldung prüfen (beim Einrichten), ohne etwas zu senden.
  Future<void> test() async {
    final ch = await _connect(server);
    try {
      await _expect(ch, 220, 'Der Server meldet sich nicht als SMTP.');
      var ehlo = await _ehlo(ch);
      if (server.security == MailSecurity.starttls) {
        await ch.write('STARTTLS\r\n');
        await _expect(ch, 220, 'STARTTLS abgelehnt.');
        await ch.upgradeToTls();
        ehlo = await _ehlo(ch);
      }
      if (!ch.isSecure) {
        throw const MailException('Nur verschlüsselte Verbindungen erlaubt.');
      }
      await _auth(ch, ehlo);
      await ch.write('QUIT\r\n');
    } finally {
      await ch.close();
    }
  }

  /// Sendet [message] (RFC 5322 mit CRLF) von [from] an [to].
  Future<void> send({
    required String from,
    required String to,
    required String message,
  }) async {
    final ch = await _connect(server);
    try {
      await _expect(ch, 220, 'Der Server meldet sich nicht als SMTP.');
      var ehlo = await _ehlo(ch);
      if (server.security == MailSecurity.starttls) {
        if (!ehlo.any((l) => l.toUpperCase().contains('STARTTLS'))) {
          throw const MailException(
            'Der Server bietet keine verschlüsselte Verbindung (STARTTLS). '
            'Ohne Verschlüsselung sendet die App nicht.',
          );
        }
        await ch.write('STARTTLS\r\n');
        await _expect(ch, 220, 'STARTTLS abgelehnt.');
        await ch.upgradeToTls();
        ehlo = await _ehlo(ch);
      }
      if (!ch.isSecure) {
        throw const MailException('Nur verschlüsselte Verbindungen erlaubt.');
      }
      await _auth(ch, ehlo);
      await ch.write('MAIL FROM:<$from>\r\n');
      await _expect(ch, 250, 'Absender abgelehnt.');
      await ch.write('RCPT TO:<$to>\r\n');
      final rcpt = await _reply(ch);
      if (rcpt.$1 != 250 && rcpt.$1 != 251) {
        throw MailException('Empfänger $to abgelehnt.');
      }
      await ch.write('DATA\r\n');
      await _expect(ch, 354, 'Der Server nimmt die Nachricht nicht an.');
      await ch.write('${dotStuff(message)}\r\n.\r\n');
      await _expect(ch, 250, 'Der Server hat die Nachricht abgelehnt.');
      await ch.write('QUIT\r\n');
    } finally {
      await ch.close();
    }
  }

  /// Zeilen, die mit „.“ beginnen, werden verdoppelt (RFC 5321 4.5.2).
  static String dotStuff(String message) {
    final m = message.endsWith('\r\n')
        ? message.substring(0, message.length - 2)
        : message;
    return m
        .split('\r\n')
        .map((l) => l.startsWith('.') ? '.$l' : l)
        .join('\r\n');
  }

  Future<List<String>> _ehlo(MailChannel ch) async {
    await ch.write('EHLO jeni-bucht.local\r\n');
    final r = await _reply(ch);
    if (r.$1 != 250) throw const MailException('EHLO abgelehnt.');
    return r.$2;
  }

  Future<void> _auth(MailChannel ch, List<String> ehlo) async {
    final auth = ehlo.firstWhere(
      (l) => l.toUpperCase().startsWith('AUTH'),
      orElse: () => 'AUTH PLAIN LOGIN',
    );
    final methods = auth.toUpperCase().split(RegExp(r'[\s=]+'));
    (int, List<String>) r;
    if (methods.contains('PLAIN') || !methods.contains('LOGIN')) {
      final token = base64Encode(
        utf8.encode('\u0000${server.user}\u0000$password'),
      );
      await ch.write('AUTH PLAIN $token\r\n');
      r = await _reply(ch);
    } else {
      await ch.write('AUTH LOGIN\r\n');
      await _expect(ch, 334, 'Anmeldung nicht möglich.');
      await ch.write('${base64Encode(utf8.encode(server.user))}\r\n');
      await _expect(ch, 334, 'Anmeldung nicht möglich.');
      await ch.write('${base64Encode(utf8.encode(password))}\r\n');
      r = await _reply(ch);
    }
    if (r.$1 != 235) {
      throw const MailException(
        'Anmeldung beim Mailserver abgelehnt. Bitte Adresse und Kennwort '
        'bzw. App-Passwort prüfen.',
        authentication: true,
      );
    }
  }

  Future<void> _expect(MailChannel ch, int code, String message) async {
    final r = await _reply(ch);
    if (r.$1 != code) throw MailException('$message (${r.$1})');
  }

  /// Mehrzeilige Antwort „250-…“ bis „250 …“.
  static Future<(int, List<String>)> _reply(MailChannel ch) async {
    final lines = <String>[];
    while (true) {
      final line = await ch.readLine();
      if (line.length < 3) continue;
      final code = int.tryParse(line.substring(0, 3)) ?? 0;
      lines.add(line.length > 4 ? line.substring(4) : '');
      if (line.length == 3 || line[3] != '-') return (code, lines);
    }
  }
}
