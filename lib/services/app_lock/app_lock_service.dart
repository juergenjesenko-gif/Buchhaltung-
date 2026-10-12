import 'dart:convert';
import 'dart:math';

import '../backup/backup_crypto.dart';

/// App-Sperre mit PIN und optional Biometrie (Lastenheft L-22.30, FA-1.13 ff.).
///
/// Reine Fachlogik ohne Plattform: PIN-Regeln, PIN-Hash, Wartezeit nach
/// Fehlversuchen und Sperrzeitpunkt. Gespeichert wird über [AppLockStore]
/// (in der App `flutter_secure_storage`, nie SQLite und nie im Klartext).
///
/// Es gibt bewusst **kein** Zurücksetzen der PIN durch den Anbieter und keine
/// Löschung nach Fehlversuchen: wer die PIN vergisst, löscht die App-Daten und
/// stellt aus der Sicherung wieder her.
class AppLockPolicy {
  const AppLockPolicy._();

  /// Mindestlänge der PIN. 6 Ziffern = 1 Mio. Kombinationen; zusammen mit der
  /// Wartezeit nach [freeAttempts] Fehlversuchen ist Raten am Gerät
  /// aussichtslos. 4 Ziffern (10.000) wären mit gängigen Mustern zu schwach.
  /// Fundstelle: NIST SP 800-63B Abschn. 5.1.1 (mind. 6 Zeichen bei
  /// Begrenzung der Fehlversuche); iOS und Android schlagen ebenfalls 6 vor.
  static const pinMinDigits = 6;

  /// Höchstlänge: genug Spielraum, ohne dass die Eingabe lästig wird.
  static const pinMaxDigits = 8;

  /// Standard-Sperrzeit im Hintergrund in Sekunden (1 Minute).
  static const defaultTimeoutSeconds = 60;

  /// Auswahl in den Einstellungen: sofort, 1, 5, 15 Minuten.
  static const timeoutChoicesSeconds = [0, 60, 300, 900];

  /// So viele Fehlversuche ohne Wartezeit.
  static const freeAttempts = 5;

  /// Erste Wartezeit nach [freeAttempts] Fehlversuchen, danach je Versuch
  /// verdoppelt bis [backoffMaxSeconds].
  static const backoffInitialSeconds = 30;
  static const backoffMaxSeconds = 3600;

  /// Argon2id wie bei der Sicherung (OWASP: 19 MiB, 2 Durchläufe).
  static const _crypto = BackupCrypto();

  static bool isValidPin(String pin) =>
      pin.length >= pinMinDigits &&
      pin.length <= pinMaxDigits &&
      RegExp(r'^[0-9]+$').hasMatch(pin);

  /// Fehlermeldung für das Formular, `null` wenn die PIN taugt.
  static String? pinError(String pin) {
    if (!RegExp(r'^[0-9]*$').hasMatch(pin)) return 'Nur Ziffern';
    if (pin.length < pinMinDigits || pin.length > pinMaxDigits) {
      return '$pinMinDigits bis $pinMaxDigits Ziffern';
    }
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) {
      return 'Nicht nur dieselbe Ziffer';
    }
    const ascending = '01234567890';
    const descending = '09876543210';
    if (ascending.contains(pin) || descending.contains(pin)) {
      return 'Keine einfache Zahlenfolge';
    }
    return null;
  }

  /// Wartezeit nach [failedAttempts] Fehlversuchen in Folge.
  static Duration backoffFor(int failedAttempts) {
    if (failedAttempts < freeAttempts) return Duration.zero;
    final steps = failedAttempts - freeAttempts;
    var seconds = backoffInitialSeconds;
    for (var i = 0; i < steps && seconds < backoffMaxSeconds; i++) {
      seconds *= 2;
    }
    return Duration(seconds: min(seconds, backoffMaxSeconds));
  }

  /// Ob die App nach [backgroundSince] beim Zurückkehren um [now] zu sperren
  /// ist. Eine rückwärts gestellte Uhr sperrt sofort (sicherer Fall).
  static bool shouldLockAfterBackground({
    required DateTime backgroundSince,
    required DateTime now,
    required int timeoutSeconds,
  }) {
    final elapsed = now.difference(backgroundSince);
    if (elapsed.isNegative) return true;
    return elapsed.inSeconds >= timeoutSeconds;
  }

  /// PIN-Hash: `v1:<Speicher>:<Durchläufe>:<Parallelität>:<Salz>:<Hash>`
  /// (Salz und Hash Base64, Salz 16 Byte zufällig).
  static Future<String> hashPin(String pin, {List<int>? salt}) async {
    final s = salt ?? _randomBytes(16);
    final hash = await BackupCrypto.deriveBytes(
      pin,
      s,
      memoryKiB: _crypto.memoryKiB,
      iterations: _crypto.iterations,
      parallelism: _crypto.parallelism,
    );
    return [
      'v1',
      _crypto.memoryKiB,
      _crypto.iterations,
      _crypto.parallelism,
      base64Encode(s),
      base64Encode(hash),
    ].join(':');
  }

  static Future<bool> verifyPin(String pin, String stored) async {
    final parts = stored.split(':');
    if (parts.length != 6 || parts[0] != 'v1') return false;
    final expected = base64Decode(parts[5]);
    final actual = await BackupCrypto.deriveBytes(
      pin,
      base64Decode(parts[4]),
      memoryKiB: int.parse(parts[1]),
      iterations: int.parse(parts[2]),
      parallelism: int.parse(parts[3]),
    );
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  static List<int> _randomBytes(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }
}

/// Schlüssel-Wert-Ablage der App-Sperre.
abstract class AppLockStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Für Tests.
class MemoryAppLockStore implements AppLockStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Ergebnis einer PIN-Eingabe.
sealed class PinResult {
  const PinResult();
}

class PinAccepted extends PinResult {
  const PinAccepted();
}

class PinRejected extends PinResult {
  const PinRejected(this.failedAttempts, this.waitUntil);
  final int failedAttempts;

  /// Bis dahin nimmt die App keine Eingabe an; `null` ohne Wartezeit.
  final DateTime? waitUntil;
}

class PinMustWait extends PinResult {
  const PinMustWait(this.waitUntil);
  final DateTime waitUntil;
}

/// Zustand und Abläufe der App-Sperre.
class AppLockService {
  AppLockService(this.store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppLockStore store;
  final DateTime Function() _clock;

  static const _kPin = 'app_lock_pin';
  static const _kBiometric = 'app_lock_biometric';
  static const _kTimeout = 'app_lock_timeout_s';
  static const _kFailed = 'app_lock_failed';
  static const _kWaitUntil = 'app_lock_wait_until';

  Future<bool> isEnabled() async => await store.read(_kPin) != null;

  Future<bool> biometricEnabled() async => await store.read(_kBiometric) == '1';

  Future<int> timeoutSeconds() async =>
      int.tryParse(await store.read(_kTimeout) ?? '') ??
      AppLockPolicy.defaultTimeoutSeconds;

  /// Schaltet die Sperre ein bzw. ändert die PIN.
  Future<void> enable(
    String pin, {
    required bool biometric,
    int timeoutSeconds = AppLockPolicy.defaultTimeoutSeconds,
  }) async {
    final error = AppLockPolicy.pinError(pin);
    if (error != null) throw ArgumentError(error);
    await store.write(_kPin, await AppLockPolicy.hashPin(pin));
    await setBiometric(biometric);
    await setTimeoutSeconds(timeoutSeconds);
    await _resetFailures();
  }

  Future<void> setBiometric(bool on) =>
      store.write(_kBiometric, on ? '1' : '0');

  Future<void> setTimeoutSeconds(int seconds) =>
      store.write(_kTimeout, '$seconds');

  /// Ausschalten nur nach richtiger PIN (Aufrufer prüft vorher).
  Future<void> disable() async {
    for (final k in [_kPin, _kBiometric, _kTimeout, _kFailed, _kWaitUntil]) {
      await store.delete(k);
    }
  }

  /// Bis wann Eingaben gesperrt sind; `null` wenn jetzt möglich.
  Future<DateTime?> waitUntil() async {
    final raw = await store.read(_kWaitUntil);
    final until = raw == null ? null : DateTime.tryParse(raw);
    if (until == null || !until.isAfter(_clock())) return null;
    return until;
  }

  Future<PinResult> checkPin(String pin) async {
    final stored = await store.read(_kPin);
    if (stored == null) return const PinAccepted();
    final wait = await waitUntil();
    if (wait != null) return PinMustWait(wait);
    if (await AppLockPolicy.verifyPin(pin, stored)) {
      await _resetFailures();
      return const PinAccepted();
    }
    final failed = (int.tryParse(await store.read(_kFailed) ?? '') ?? 0) + 1;
    await store.write(_kFailed, '$failed');
    final backoff = AppLockPolicy.backoffFor(failed);
    DateTime? until;
    if (backoff > Duration.zero) {
      until = _clock().add(backoff);
      await store.write(_kWaitUntil, until.toIso8601String());
    }
    return PinRejected(failed, until);
  }

  /// Erfolgreiche Biometrie setzt den Fehlerzähler zurück.
  Future<void> biometricSucceeded() => _resetFailures();

  Future<void> _resetFailures() async {
    await store.delete(_kFailed);
    await store.delete(_kWaitUntil);
  }
}
