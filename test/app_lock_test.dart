import 'package:buchhaltung/services/app_lock/app_lock_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PIN-Regeln', () {
    test('Länge und nur Ziffern', () {
      expect(AppLockPolicy.pinError('12345'), isNotNull);
      expect(AppLockPolicy.pinError('123456789'), isNotNull);
      expect(AppLockPolicy.pinError('12a456'), 'Nur Ziffern');
      expect(AppLockPolicy.pinError('271828'), isNull);
      expect(AppLockPolicy.pinError('27182818'), isNull);
    });

    test('Triviale PINs abgelehnt', () {
      expect(AppLockPolicy.pinError('000000'), isNotNull);
      expect(AppLockPolicy.pinError('123456'), isNotNull);
      expect(AppLockPolicy.pinError('876543'), isNotNull);
    });
  });

  test('Wartezeit steigt nach freien Versuchen und ist gedeckelt', () {
    expect(AppLockPolicy.backoffFor(4), Duration.zero);
    expect(AppLockPolicy.backoffFor(5), const Duration(seconds: 30));
    expect(AppLockPolicy.backoffFor(6), const Duration(seconds: 60));
    expect(AppLockPolicy.backoffFor(7), const Duration(seconds: 120));
    expect(AppLockPolicy.backoffFor(50), const Duration(hours: 1));
  });

  test('Sperre nach Zeit im Hintergrund, rückwärts gestellte Uhr sperrt', () {
    final t = DateTime(2026, 10, 12, 10);
    bool lock(Duration d, int timeout) =>
        AppLockPolicy.shouldLockAfterBackground(
          backgroundSince: t,
          now: t.add(d),
          timeoutSeconds: timeout,
        );
    expect(lock(const Duration(seconds: 59), 60), isFalse);
    expect(lock(const Duration(seconds: 60), 60), isTrue);
    expect(lock(Duration.zero, 0), isTrue);
    expect(lock(const Duration(seconds: -5), 60), isTrue);
  });

  test('PIN-Hash: kein Klartext, gesalzen, prüfbar', () async {
    final a = await AppLockPolicy.hashPin('271828');
    final b = await AppLockPolicy.hashPin('271828');
    expect(a, isNot(contains('271828')));
    expect(a, isNot(b), reason: 'zufälliges Salz');
    expect(a, startsWith('v1:19456:2:1:'));
    expect(await AppLockPolicy.verifyPin('271828', a), isTrue);
    expect(await AppLockPolicy.verifyPin('271829', a), isFalse);
    expect(await AppLockPolicy.verifyPin('271828', 'kaputt'), isFalse);
  });

  test('Dienst: Fehlversuche, Wartezeit, Zurücksetzen', () async {
    var now = DateTime(2026, 10, 12, 10);
    final store = MemoryAppLockStore();
    final service = AppLockService(store, clock: () => now);
    expect(await service.isEnabled(), isFalse);
    await service.enable('271828', biometric: true);
    expect(await service.isEnabled(), isTrue);
    expect(await service.biometricEnabled(), isTrue);
    expect(await service.timeoutSeconds(), 60);
    expect(store.values.values.join(), isNot(contains('271828')));

    for (var i = 1; i <= 4; i++) {
      final r = await service.checkPin('000001');
      expect(r, isA<PinRejected>());
      expect((r as PinRejected).waitUntil, isNull);
    }
    final fifth = await service.checkPin('000001') as PinRejected;
    expect(fifth.waitUntil, now.add(const Duration(seconds: 30)));
    // Auch die richtige PIN wird während der Wartezeit nicht angenommen.
    expect(await service.checkPin('271828'), isA<PinMustWait>());

    now = now.add(const Duration(seconds: 31));
    expect(await service.checkPin('271828'), isA<PinAccepted>());
    // Zähler zurückgesetzt
    expect((await service.checkPin('000001') as PinRejected).failedAttempts, 1);

    await service.disable();
    expect(await service.isEnabled(), isFalse);
    expect(store.values, isEmpty);
  });

  test('Ungültige PIN wird nicht gespeichert', () async {
    final service = AppLockService(MemoryAppLockStore());
    expect(() => service.enable('1234', biometric: false), throwsArgumentError);
  });
}
