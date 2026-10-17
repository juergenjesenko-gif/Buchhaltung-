import 'dart:convert';
import 'dart:typed_data';

import 'mail_channel.dart';
import 'mail_server.dart';

/// Eine Mail aus dem Postfach, wie das Hauptgerät sie sieht.
class FetchedMail {
  const FetchedMail({
    required this.uid,
    required this.messageId,
    required this.subject,
    this.raw,
  });

  final int uid;
  final String messageId;
  final String subject;

  /// Ganze Nachricht (RFC 5322), nur wenn abgerufen.
  final String? raw;
}

/// Antwort auf einen IMAP-Befehl: Status und alle Zeilen samt Literalen.
class _Response {
  _Response(this.status, this.text, this.lines);
  final String status;
  final String text;
  final List<String> lines;
}

/// Nur-Lese-Zugriff auf ein IMAP-Postfach (RFC 9051/3501), FA-17.9.
///
/// Befehle: `LOGIN`, `EXAMINE` (Ordner nur lesen), `UID SEARCH`,
/// `UID FETCH … BODY.PEEK[…]` (setzt kein „gelesen“), `LOGOUT`. Es gibt
/// bewusst kein `STORE`, `COPY`, `MOVE`, `EXPUNGE` oder `DELETE`: die App
/// verändert, verschiebt und löscht keine Mail.
class ImapReader {
  ImapReader(this.server, this.password, {MailConnector? connector})
    : _connect = connector ?? IoMailChannel.connect;

  final MailServer server;
  final String password;
  final MailConnector _connect;

  MailChannel? _ch;
  int _tag = 0;

  /// Befehle, die dieser Client je sendet (Test der Nur-Lese-Zusage).
  static const allowedCommands = {
    'CAPABILITY',
    'STARTTLS',
    'LOGIN',
    'EXAMINE',
    'UID SEARCH',
    'UID FETCH',
    'LOGOUT',
  };

  Future<void> open() async {
    final ch = await _connect(server);
    _ch = ch;
    final greeting = await ch.readLine();
    if (!greeting.startsWith('* OK') && !greeting.startsWith('* PREAUTH')) {
      throw const MailException('Der Server meldet sich nicht als IMAP.');
    }
    if (server.security == MailSecurity.starttls) {
      final r = await _command('STARTTLS');
      if (r.status != 'OK') {
        throw const MailException(
          'Der Server bietet keine verschlüsselte Verbindung (STARTTLS). '
          'Ohne Verschlüsselung verbindet die App nicht.',
        );
      }
      await ch.upgradeToTls();
    }
    if (!ch.isSecure) {
      throw const MailException('Nur verschlüsselte Verbindungen erlaubt.');
    }
    final login = await _command(
      'LOGIN ${_quote(server.user)} ${_quote(password)}',
    );
    if (login.status != 'OK') {
      throw const MailException(
        'Anmeldung am Postfach abgelehnt. Bitte Benutzer und Kennwort bzw. '
        'App-Passwort prüfen.',
        authentication: true,
      );
    }
    final ex = await _command('EXAMINE INBOX');
    if (ex.status != 'OK') {
      throw const MailException('Posteingang lässt sich nicht öffnen.');
    }
  }

  /// UIDs aller Mails, deren Betreff [text] enthält (Server sucht
  /// Teilzeichenfolge, ohne Groß-/Kleinschreibung).
  Future<List<int>> searchSubject(String text) async {
    final r = await _command('UID SEARCH SUBJECT ${_quote(text)}');
    if (r.status != 'OK') return const [];
    final uids = <int>[];
    for (final line in r.lines) {
      final m = RegExp(r'^\* SEARCH\b(.*)$').firstMatch(line);
      if (m == null) continue;
      for (final n in m.group(1)!.trim().split(RegExp(r'\s+'))) {
        final v = int.tryParse(n);
        if (v != null) uids.add(v);
      }
    }
    return uids;
  }

  /// Message-ID und Betreff, ohne die Mail als gelesen zu markieren.
  Future<FetchedMail?> header(int uid) async {
    final r = await _command(
      'UID FETCH $uid (BODY.PEEK[HEADER.FIELDS (MESSAGE-ID SUBJECT)])',
    );
    if (r.status != 'OK') return null;
    final text = r.lines.join('\n');
    final id = RegExp(
      r'^message-id:\s*<?([^>\s]+)>?',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);
    final subject = _unfoldHeader(text, 'subject');
    return FetchedMail(
      uid: uid,
      // Ohne Message-ID: UID als Ersatz, damit nichts doppelt kommt.
      messageId: id?.group(1) ?? 'uid-$uid@${server.host}',
      subject: subject ?? '',
    );
  }

  /// Ganze Nachricht (BODY.PEEK[], ohne „gelesen“).
  Future<String?> body(int uid) async {
    final r = await _command('UID FETCH $uid (BODY.PEEK[])');
    if (r.status != 'OK') return null;
    // Größtes Literal ist die Nachricht.
    String? best;
    for (final l in r.lines) {
      if (best == null || l.length > best.length) best = l;
    }
    return best;
  }

  Future<void> close() async {
    final ch = _ch;
    if (ch == null) return;
    try {
      await _command('LOGOUT');
    } on Object {
      // Abbau ist best effort.
    }
    await ch.close();
    _ch = null;
  }

  static String? _unfoldHeader(String text, String name) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (!l.toLowerCase().startsWith('$name:')) continue;
      var value = l.substring(name.length + 1).trim();
      for (var j = i + 1; j < lines.length; j++) {
        final n = lines[j];
        if (n.startsWith(' ') || n.startsWith('\t')) {
          value = '$value ${n.trim()}';
        } else {
          break;
        }
      }
      return value.replaceAll('\r', '');
    }
    return null;
  }

  /// IMAP-Zeichenkette in Anführungszeichen; `\` und `"` werden maskiert.
  static String _quote(String s) =>
      '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

  Future<_Response> _command(String command) async {
    final ch = _ch;
    if (ch == null) throw StateError('nicht verbunden');
    final verb = command.startsWith('UID ')
        ? command.split(' ').take(2).join(' ')
        : command.split(' ').first;
    assert(allowedCommands.contains(verb), 'IMAP-Befehl $verb nicht erlaubt');
    final tag = 'J${++_tag}';
    await ch.write('$tag $command\r\n');
    final lines = <String>[];
    while (true) {
      var line = await ch.readLine();
      if (line.startsWith('$tag ')) {
        final rest = line.substring(tag.length + 1);
        final sp = rest.indexOf(' ');
        return _Response(
          (sp < 0 ? rest : rest.substring(0, sp)).toUpperCase(),
          sp < 0 ? '' : rest.substring(sp + 1),
          lines,
        );
      }
      // Literale {n}: Inhalt folgt roh; danach geht die Zeile weiter.
      while (true) {
        final lit = RegExp(r'\{(\d+)\}$').firstMatch(line);
        if (lit == null) break;
        final Uint8List bytes = await ch.readBytes(int.parse(lit.group(1)!));
        lines
          ..add(line)
          ..add(latin1.decode(bytes));
        line = await ch.readLine();
      }
      lines.add(line);
    }
  }
}
