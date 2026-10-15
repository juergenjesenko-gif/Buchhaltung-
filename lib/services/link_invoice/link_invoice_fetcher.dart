import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Rechnung über einen Link-QR laden (L-27.7). Nur nach Tipp der Nutzerin,
/// nur `https`, keine Cookies, kein Login, keine Weiterleitung auf eine andere
/// Domain ohne erneute Bestätigung, nur PDF oder XML, höchstens [maxBytes].
///
/// Übertragen werden nur die Adresse aus dem QR-Code, IP-Adresse und
/// technische Verbindungsdaten an den Server dieser Domain – keine Belegdaten
/// (Lastenheft 5.19, PRIVACY, STORE_LISTING; Prüfpunkt P-R35).
class LinkInvoiceFetcher {
  LinkInvoiceFetcher({LinkTransport? transport})
    : _transport = transport ?? _HttpTransport();

  final LinkTransport _transport;

  static const maxBytes = 20 * 1024 * 1024;
  static const maxRedirects = 5;
  static const timeout = Duration(seconds: 30);

  /// Lädt [uri]. [confirmedHost] ist die Domain, die die Nutzerin bestätigt
  /// hat; eine Weiterleitung auf eine andere Domain bricht mit
  /// [LinkRedirect] ab, damit die App die neue Domain zeigen kann.
  Future<LinkResult> fetch(Uri uri, {required String confirmedHost}) async {
    var current = uri;
    for (var i = 0; i <= maxRedirects; i++) {
      if (current.scheme != 'https' || current.userInfo.isNotEmpty) {
        return const LinkRejected('Nur sichere https-Adressen werden geladen.');
      }
      if (current.host.toLowerCase() != confirmedHost.toLowerCase()) {
        return LinkRedirect(current);
      }
      final LinkResponse response;
      try {
        response = await _transport.get(current, maxBytes).timeout(timeout);
      } on LinkTooLarge {
        return const LinkRejected('Die Datei ist größer als 20 MB.');
      } on TimeoutException {
        return const LinkRejected('Der Server antwortet nicht.');
      } on IOException {
        return const LinkRejected('Keine Verbindung zum Server.');
      }
      if (response.status >= 300 && response.status < 400) {
        final location = response.location;
        if (location == null) {
          return const LinkRejected('Ungültige Weiterleitung.');
        }
        current = current.resolve(location);
        continue;
      }
      if (response.status != 200) {
        return LinkNeedsBrowser(
          current,
          'Der Server meldet ${response.status}.',
        );
      }
      final kind = _kind(response.contentType, response.body);
      if (kind == null) {
        // HTML-Seite, Login o. Ä.: nicht in der App, sondern im Browser.
        return LinkNeedsBrowser(
          current,
          'Die Seite enthält keine PDF- oder XML-Rechnung.',
        );
      }
      return LinkFile(current, response.body, kind);
    }
    return const LinkRejected('Zu viele Weiterleitungen.');
  }

  /// `pdf` oder `xml` nach Inhalt (Signatur) – der Content-Type allein
  /// genügt nicht.
  static String? _kind(String? contentType, Uint8List body) {
    if (body.length > 4 &&
        body[0] == 0x25 &&
        body[1] == 0x50 &&
        body[2] == 0x44 &&
        body[3] == 0x46) {
      return 'pdf';
    }
    final head = String.fromCharCodes(
      body.take(200).where((b) => b < 128),
    ).trimLeft();
    final type = (contentType ?? '').toLowerCase();
    if (head.startsWith('<?xml') ||
        (type.contains('xml') && head.startsWith('<'))) {
      if (head.toLowerCase().contains('<html')) return null;
      return 'xml';
    }
    return null;
  }
}

sealed class LinkResult {
  const LinkResult();
}

/// Geladene Datei: [kind] ist `pdf` oder `xml`.
class LinkFile extends LinkResult {
  const LinkFile(this.uri, this.bytes, this.kind);
  final Uri uri;
  final Uint8List bytes;
  final String kind;
}

/// Weiterleitung auf eine andere Domain – erst nach erneuter Anzeige laden.
class LinkRedirect extends LinkResult {
  const LinkRedirect(this.target);
  final Uri target;
}

/// Keine Rechnungsdatei: „Im Browser öffnen“ anbieten.
class LinkNeedsBrowser extends LinkResult {
  const LinkNeedsBrowser(this.uri, this.reason);
  final Uri uri;
  final String reason;
}

class LinkRejected extends LinkResult {
  const LinkRejected(this.reason);
  final String reason;
}

/// Antwort ohne automatische Weiterleitung.
class LinkResponse {
  const LinkResponse({
    required this.status,
    required this.body,
    this.location,
    this.contentType,
  });
  final int status;
  final Uint8List body;
  final String? location;
  final String? contentType;
}

class LinkTooLarge implements Exception {
  const LinkTooLarge();
}

abstract class LinkTransport {
  Future<LinkResponse> get(Uri uri, int maxBytes);
}

class _HttpTransport implements LinkTransport {
  @override
  Future<LinkResponse> get(Uri uri, int maxBytes) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'JeNi-bucht-App';
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/pdf, application/xml, text/xml',
      );
      final response = await request.close();
      if (response.contentLength > maxBytes) throw const LinkTooLarge();
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        if (builder.length > maxBytes) throw const LinkTooLarge();
      }
      return LinkResponse(
        status: response.statusCode,
        body: builder.takeBytes(),
        location: response.headers.value(HttpHeaders.locationHeader),
        contentType: response.headers.contentType?.mimeType,
      );
    } finally {
      client.close(force: true);
    }
  }
}
