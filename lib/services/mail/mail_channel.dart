import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'mail_server.dart';

/// Zeilenorientierte Verbindung zu einem Mailserver. Die Protokolle (IMAP,
/// SMTP) sprechen nur über diese Schnittstelle, damit Tests einen Ersatz-
/// Server einsetzen können (FA-17.9).
abstract interface class MailChannel {
  /// Nächste Zeile ohne CRLF.
  Future<String> readLine();

  /// Genau [count] Bytes (IMAP-Literal).
  Future<Uint8List> readBytes(int count);

  /// Schreibt [text] unverändert (Aufrufer setzt CRLF).
  Future<void> write(String text);

  /// STARTTLS: Verbindung auf TLS umstellen.
  Future<void> upgradeToTls();

  /// Ist die Verbindung verschlüsselt?
  bool get isSecure;

  Future<void> close();
}

/// Öffnet eine Verbindung zu [server]. Tests übergeben einen eigenen Öffner.
typedef MailConnector = Future<MailChannel> Function(MailServer server);

/// Echte Verbindung über `dart:io` (RawSocket/RawSecureSocket). TLS-Zertifikate
/// prüft das System; ein ungültiges Zertifikat bricht ab (kein Ausweichen auf
/// unverschlüsselt, FA-17.9).
class IoMailChannel implements MailChannel {
  IoMailChannel._(this._host, this._socket) {
    _listen();
  }

  static const timeout = Duration(seconds: 30);

  /// Verbindet; bei [MailSecurity.tls] sofort verschlüsselt.
  static Future<MailChannel> connect(MailServer server) async {
    try {
      final RawSocket socket = server.security == MailSecurity.tls
          ? await RawSecureSocket.connect(
              server.host,
              server.port,
              timeout: timeout,
            )
          : await RawSocket.connect(server.host, server.port, timeout: timeout);
      return IoMailChannel._(server.host, socket);
    } on HandshakeException {
      throw const MailException(
        'Die sichere Verbindung zum Mailserver ist fehlgeschlagen '
        '(Zertifikat). Bitte Server und Port prüfen.',
      );
    } on SocketException {
      throw MailException(
        'Mailserver ${server.host} nicht erreichbar. Besteht eine '
        'Internetverbindung?',
      );
    }
  }

  final String _host;
  RawSocket _socket;
  StreamSubscription<RawSocketEvent>? _sub;
  final _buffer = BytesBuilder(copy: false);
  Uint8List _pending = Uint8List(0);
  Completer<void>? _dataWaiter;
  Completer<void>? _writeWaiter;
  bool _closed = false;

  @override
  bool get isSecure => _socket is RawSecureSocket;

  void _listen() {
    _sub = _socket.listen(
      _onEvent,
      onError: (Object _) => _wake(closed: true),
      onDone: () => _wake(closed: true),
    );
  }

  void _onEvent(RawSocketEvent e) {
    switch (e) {
      case RawSocketEvent.read:
        final data = _socket.read();
        if (data != null) {
          _buffer.add(data);
          _wake();
        }
      case RawSocketEvent.write:
        final w = _writeWaiter;
        _writeWaiter = null;
        w?.complete();
      case RawSocketEvent.readClosed:
      case RawSocketEvent.closed:
        _wake(closed: true);
    }
  }

  void _wake({bool closed = false}) {
    if (closed) _closed = true;
    final w = _dataWaiter;
    _dataWaiter = null;
    w?.complete();
    if (closed) {
      final ww = _writeWaiter;
      _writeWaiter = null;
      ww?.complete();
    }
  }

  void _absorb() {
    if (_buffer.isEmpty) return;
    final more = _buffer.takeBytes();
    _pending = _pending.isEmpty
        ? more
        : (BytesBuilder(copy: false)
                ..add(_pending)
                ..add(more))
              .takeBytes();
  }

  Future<void> _waitData() async {
    if (_closed) {
      throw const MailException('Der Mailserver hat die Verbindung beendet.');
    }
    _dataWaiter ??= Completer<void>();
    await _dataWaiter!.future.timeout(
      timeout,
      onTimeout: () => throw const MailException(
        'Der Mailserver antwortet nicht (Zeitüberschreitung).',
      ),
    );
  }

  @override
  Future<String> readLine() async {
    while (true) {
      _absorb();
      for (var i = 0; i + 1 < _pending.length; i++) {
        if (_pending[i] == 13 && _pending[i + 1] == 10) {
          final line = latin1.decode(_pending.sublist(0, i));
          _pending = _pending.sublist(i + 2);
          return line;
        }
      }
      await _waitData();
    }
  }

  @override
  Future<Uint8List> readBytes(int count) async {
    while (true) {
      _absorb();
      if (_pending.length >= count) {
        final out = _pending.sublist(0, count);
        _pending = _pending.sublist(count);
        return out;
      }
      await _waitData();
    }
  }

  @override
  Future<void> write(String text) async {
    var bytes = Uint8List.fromList(latin1.encode(text));
    while (bytes.isNotEmpty) {
      if (_closed) {
        throw const MailException('Der Mailserver hat die Verbindung beendet.');
      }
      final n = _socket.write(bytes);
      if (n >= bytes.length) return;
      bytes = bytes.sublist(n);
      _writeWaiter ??= Completer<void>();
      _socket.writeEventsEnabled = true;
      await _writeWaiter!.future.timeout(
        timeout,
        onTimeout: () =>
            throw const MailException('Senden an den Mailserver hängt.'),
      );
    }
  }

  @override
  Future<void> upgradeToTls() async {
    if (isSecure) return;
    final sub = _sub!;
    _sub = null;
    try {
      _socket = await RawSecureSocket.secure(
        _socket,
        subscription: sub,
        host: _host,
      );
    } on HandshakeException {
      throw const MailException(
        'Die sichere Verbindung (STARTTLS) ist fehlgeschlagen.',
      );
    }
    _pending = Uint8List(0);
    _buffer.clear();
    _listen();
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _sub?.cancel();
    await _socket.close();
  }
}
