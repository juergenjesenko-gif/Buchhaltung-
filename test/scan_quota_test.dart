import 'package:buchhaltung/services/licensing/scan_quota.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gratis-Belegerkennung in Basis (FA-13.2): 5 je Kalendermonat, Neustart
/// am 1., kein negativer Rest.
void main() {
  final okt = DateTime(2026, 10, 31, 23, 59);
  final nov = DateTime(2026, 11, 1, 0, 1);

  test('ohne Verbrauch volle 5', () {
    expect(ScanQuota.remaining(null, okt), 5);
  });

  test('zählt im Monat herunter und nie unter 0', () {
    String? stored;
    for (var i = 0; i < 7; i++) {
      stored = ScanQuota.consume(stored, okt);
    }
    expect(stored, '2026-10:7');
    expect(ScanQuota.remaining(stored, okt), 0);
  });

  test('neuer Monat beginnt wieder bei 5', () {
    final stored = ScanQuota.consume('2026-10:5', okt);
    expect(ScanQuota.remaining(stored, nov), 5);
    expect(ScanQuota.consume(stored, nov), '2026-11:1');
  });

  test('unlesbarer Wert zählt als unverbraucht', () {
    expect(ScanQuota.remaining('kaputt', okt), 5);
  });
}
