// Ersatz-Mailserver für Tests des Mailwegs (FA-17.9): ein Postfach im
// Speicher, ein IMAP- und ein SMTP-Kanal, die genau so viel Protokoll
// sprechen, wie die App benutzt. Jeder Befehl wird mitgeschrieben, damit die
// Tests die Nur-Lese-Zusage prüfen können.
import 'dart:convert';
import 'dart:typed_data';

import 'package:buchhaltung/services/mail/mail_channel.dart';
import 'package:buchhaltung/services/mail/mail_server.dart';
import 'package:buchhaltung/services/mail/mime.dart';

class FakeMailbox {
  FakeMailbox({this.password = 'geheim'});

  final String password;

  /// Nachrichten in Reihenfolge; UID = Index + 1.
  final messages = <String>[];

  /// Alle IMAP-Befehle (ohne Tag).
  final imapCommands = <String>[];

  /// Eingeloggte Benutzer (SMTP und IMAP).
  final logins = <String>[];

  /// Gesendete Umschläge (von, an).
  final envelopes = <(String, String)>[];

  int imapConnections = 0;
  bool offerStartTls = true;

  MailConnector get connector => (server) async {
    if (server.host.startsWith('smtp')) return FakeSmtpChannel(this, server);
    imapConnections++;
    return FakeImapChannel(this, server);
  };
}

abstract class _FakeChannel implements MailChannel {
  _FakeChannel(MailServer server)
    : _secure = server.security == MailSecurity.tls;

  final _out = <int>[];
  bool _secure;

  void reply(String text) => _out.addAll(latin1.encode(text));

  @override
  bool get isSecure => _secure;

  @override
  Future<void> upgradeToTls() async => _secure = true;

  @override
  Future<String> readLine() async {
    for (var i = 0; i + 1 < _out.length; i++) {
      if (_out[i] == 13 && _out[i + 1] == 10) {
        final line = latin1.decode(_out.sublist(0, i));
        _out.removeRange(0, i + 2);
        return line;
      }
    }
    throw const MailException('Verbindung beendet (Ersatzserver)');
  }

  @override
  Future<Uint8List> readBytes(int count) async {
    final b = Uint8List.fromList(_out.sublist(0, count));
    _out.removeRange(0, count);
    return b;
  }

  @override
  Future<void> close() async {}
}

class FakeImapChannel extends _FakeChannel {
  FakeImapChannel(this.box, super.server) {
    reply('* OK Ersatz-IMAP bereit\r\n');
  }

  final FakeMailbox box;

  static String? _subject(String m) => Mime.split(m).$1['subject'];
  static String? _messageId(String m) => Mime.split(m).$1['message-id'];

  @override
  Future<void> write(String text) async {
    final line = text.trimRight();
    final sp = line.indexOf(' ');
    final tag = line.substring(0, sp);
    final cmd = line.substring(sp + 1);
    box.imapCommands.add(cmd);
    final upper = cmd.toUpperCase();
    if (upper == 'STARTTLS') {
      reply(box.offerStartTls ? '$tag OK Los\r\n' : '$tag BAD nein\r\n');
    } else if (upper.startsWith('LOGIN ')) {
      final args = RegExp(r'"((?:[^"\\]|\\.)*)"').allMatches(cmd).toList();
      final user = args[0].group(1)!;
      final pass = args[1].group(1)!.replaceAll(r'\"', '"');
      if (pass == box.password) {
        box.logins.add(user);
        reply('$tag OK angemeldet\r\n');
      } else {
        reply('$tag NO [AUTHENTICATIONFAILED] falsch\r\n');
      }
    } else if (upper == 'EXAMINE INBOX') {
      reply('* ${box.messages.length} EXISTS\r\n$tag OK [READ-ONLY] ok\r\n');
    } else if (upper.startsWith('UID SEARCH SUBJECT ')) {
      final needle = RegExp(r'"(.*)"').firstMatch(cmd)!.group(1)!.toLowerCase();
      final hits = [
        for (var i = 0; i < box.messages.length; i++)
          if ((_subject(box.messages[i]) ?? '').toLowerCase().contains(needle))
            i + 1,
      ];
      reply('* SEARCH ${hits.join(' ')}\r\n$tag OK fertig\r\n');
    } else if (upper.startsWith('UID FETCH ')) {
      final uid = int.parse(cmd.split(' ')[2]);
      final m = box.messages[uid - 1];
      final String literal;
      if (upper.contains('HEADER.FIELDS')) {
        final id = _messageId(m);
        literal =
            '${id == null ? '' : 'Message-ID: $id\r\n'}'
            'Subject: ${_subject(m) ?? ''}\r\n\r\n';
      } else {
        literal = m;
      }
      final n = latin1.encode(literal).length;
      reply('* $uid FETCH (UID $uid BODY[] {$n}\r\n$literal)\r\n');
      reply('$tag OK fertig\r\n');
    } else if (upper == 'LOGOUT') {
      reply('* BYE\r\n$tag OK tschüss\r\n');
    } else {
      reply('$tag BAD unbekannt\r\n');
    }
  }
}

class FakeSmtpChannel extends _FakeChannel {
  FakeSmtpChannel(this.box, super.server) {
    reply('220 Ersatz-SMTP\r\n');
  }

  final FakeMailbox box;
  bool _data = false;
  final _body = StringBuffer();
  String _from = '';
  String _to = '';

  @override
  Future<void> write(String text) async {
    if (_data) {
      _body.write(text);
      final s = _body.toString();
      if (s.endsWith('\r\n.\r\n')) {
        final content = s
            .substring(0, s.length - 5)
            .split('\r\n')
            .map((l) => l.startsWith('..') ? l.substring(1) : l)
            .join('\r\n');
        box.messages.add('$content\r\n');
        box.envelopes.add((_from, _to));
        _data = false;
        _body.clear();
        reply('250 angenommen\r\n');
      }
      return;
    }
    final line = text.trimRight();
    final upper = line.toUpperCase();
    if (upper.startsWith('EHLO')) {
      reply(
        '250-ersatz\r\n250-AUTH PLAIN LOGIN\r\n'
        '${box.offerStartTls ? '250-STARTTLS\r\n' : ''}250 SIZE 1000000\r\n',
      );
    } else if (upper == 'STARTTLS') {
      reply('220 Los\r\n');
    } else if (upper.startsWith('AUTH PLAIN ')) {
      final parts = utf8
          .decode(base64Decode(line.substring(11)))
          .split('\u0000');
      if (parts[2] == box.password) {
        box.logins.add(parts[1]);
        reply('235 ok\r\n');
      } else {
        reply('535 falsch\r\n');
      }
    } else if (upper.startsWith('MAIL FROM:')) {
      _from = RegExp('<(.*)>').firstMatch(line)!.group(1)!;
      reply('250 ok\r\n');
    } else if (upper.startsWith('RCPT TO:')) {
      _to = RegExp('<(.*)>').firstMatch(line)!.group(1)!;
      reply('250 ok\r\n');
    } else if (upper == 'DATA') {
      _data = true;
      reply('354 los\r\n');
    } else if (upper == 'QUIT') {
      reply('221 tschüss\r\n');
    } else {
      reply('500 unbekannt\r\n');
    }
  }
}
