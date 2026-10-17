import 'dart:convert';
import 'dart:typed_data';

/// Minimaler MIME-Bau und -Zerleger für Belegmails (FA-17.9): eine Textzeile
/// und ein Anhang `.jenibeleg` in Base64. Reines Dart.
abstract final class Mime {
  /// Baut eine Mail nach RFC 5322/2045 mit einem Anhang. Zeilenende CRLF,
  /// Base64-Zeilen höchstens 76 Zeichen.
  static String build({
    required String from,
    required String to,
    required String subject,
    required DateTime date,
    required String messageId,
    required String text,
    required String attachmentName,
    required Uint8List attachment,
    String? boundary,
  }) {
    final b = boundary ?? 'jeni-${messageId.hashCode.toUnsigned(32)}-b';
    final out = StringBuffer()
      ..write('From: $from\r\n')
      ..write('To: $to\r\n')
      ..write('Subject: ${_encodeHeader(subject)}\r\n')
      ..write('Date: ${rfc5322Date(date)}\r\n')
      ..write('Message-ID: <$messageId>\r\n')
      ..write('MIME-Version: 1.0\r\n')
      ..write('Content-Type: multipart/mixed; boundary="$b"\r\n')
      ..write('\r\n')
      ..write('--$b\r\n')
      ..write('Content-Type: text/plain; charset=utf-8\r\n')
      ..write('Content-Transfer-Encoding: base64\r\n\r\n')
      ..write(_lines(base64Encode(utf8.encode(text))))
      ..write('--$b\r\n')
      ..write(
        'Content-Type: application/octet-stream; name="$attachmentName"\r\n',
      )
      ..write('Content-Transfer-Encoding: base64\r\n')
      ..write(
        'Content-Disposition: attachment; filename="$attachmentName"\r\n\r\n',
      )
      ..write(_lines(base64Encode(attachment)))
      ..write('--$b--\r\n');
    return out.toString();
  }

  static String _lines(String b64) {
    final out = StringBuffer();
    for (var i = 0; i < b64.length; i += 76) {
      out
        ..write(b64.substring(i, i + 76 > b64.length ? b64.length : i + 76))
        ..write('\r\n');
    }
    return out.toString();
  }

  static String _encodeHeader(String value) {
    if (value.codeUnits.every((c) => c >= 32 && c < 127)) return value;
    return '=?utf-8?B?${base64Encode(utf8.encode(value))}?=';
  }

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Datum nach RFC 5322 in UTC.
  static String rfc5322Date(DateTime d) {
    final u = d.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${_days[u.weekday - 1]}, ${two(u.day)} ${_months[u.month - 1]} '
        '${u.year} ${two(u.hour)}:${two(u.minute)}:${two(u.second)} +0000';
  }

  /// Kopfzeilen (entfaltet, Namen klein) und Rumpf einer Nachricht.
  static (Map<String, String>, String) split(String message) {
    final normalized = message.replaceAll('\r\n', '\n');
    final end = normalized.indexOf('\n\n');
    final head = end < 0 ? normalized : normalized.substring(0, end);
    final body = end < 0 ? '' : normalized.substring(end + 2);
    return (headers(head), body);
  }

  /// Kopfzeilen; Folgezeilen (mit Leerraum) werden angehängt.
  static Map<String, String> headers(String head) {
    final out = <String, String>{};
    String? last;
    for (final line in head.replaceAll('\r\n', '\n').split('\n')) {
      if (line.isEmpty) continue;
      if ((line.startsWith(' ') || line.startsWith('\t')) && last != null) {
        out[last] = '${out[last]} ${line.trim()}';
        continue;
      }
      final i = line.indexOf(':');
      if (i <= 0) continue;
      last = line.substring(0, i).trim().toLowerCase();
      out.putIfAbsent(last, () => line.substring(i + 1).trim());
    }
    return out;
  }

  /// Dekodiert „encoded words“ (RFC 2047) in Betreffzeilen weitergeleiteter
  /// Mails; Unbekanntes bleibt stehen.
  static String decodeHeader(String value) => value.replaceAllMapped(
    RegExp(r'=\?([^?]+)\?([bBqQ])\?([^?]*)\?=\s*'),
    (m) {
      try {
        final raw = m.group(2)!.toUpperCase() == 'B'
            ? base64Decode(base64.normalize(m.group(3)!))
            : latin1.encode(
                m
                    .group(3)!
                    .replaceAll('_', ' ')
                    .replaceAllMapped(
                      RegExp(r'=([0-9A-Fa-f]{2})'),
                      (h) => String.fromCharCode(
                        int.parse(h.group(1)!, radix: 16),
                      ),
                    ),
              );
        return m.group(1)!.toLowerCase().contains('utf')
            ? utf8.decode(raw, allowMalformed: true)
            : latin1.decode(raw);
      } on Object {
        return m.group(0)!;
      }
    },
  );

  /// Parameter aus einer Kopfzeile, z. B. `boundary` oder `filename`.
  static String? param(String header, String name) {
    final m = RegExp(
      '(?:^|;)\\s*$name\\*?=\\s*(?:"([^"]*)"|([^;\\s]+))',
      caseSensitive: false,
    ).firstMatch(header);
    if (m == null) return null;
    return m.group(1) ?? m.group(2);
  }

  /// Alle Anhänge, deren Dateiname auf [extension] endet, auch in
  /// verschachtelten Teilen (weitergeleitete Mail, `multipart/alternative`).
  static List<(String name, Uint8List bytes)> attachments(
    String message, {
    required String extension,
  }) {
    final out = <(String, Uint8List)>[];
    _collect(message, extension.toLowerCase(), out, 0);
    return out;
  }

  static void _collect(
    String part,
    String ext,
    List<(String, Uint8List)> out,
    int depth,
  ) {
    if (depth > 8) return;
    final (h, body) = split(part);
    final type = h['content-type'] ?? 'text/plain';
    if (type.toLowerCase().startsWith('multipart/')) {
      final boundary = param(type, 'boundary');
      if (boundary == null) return;
      final pieces = body.split('--$boundary');
      for (var i = 1; i < pieces.length; i++) {
        final piece = pieces[i];
        if (piece.startsWith('--')) break;
        _collect(piece.replaceFirst(RegExp(r'^\n'), ''), ext, out, depth + 1);
      }
      return;
    }
    if (type.toLowerCase().startsWith('message/rfc822')) {
      _collect(body, ext, out, depth + 1);
      return;
    }
    final name =
        param(h['content-disposition'] ?? '', 'filename') ??
        param(type, 'name');
    if (name == null || !name.toLowerCase().endsWith(ext)) return;
    final encoding = (h['content-transfer-encoding'] ?? '').toLowerCase();
    if (encoding != 'base64') return;
    try {
      out.add((
        name,
        base64Decode(body.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '')),
      ));
    } on FormatException {
      // Beschädigter Anhang: wird übergangen.
    }
  }
}
