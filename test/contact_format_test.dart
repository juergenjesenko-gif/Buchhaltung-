import 'package:flutter_test/flutter_test.dart';
import 'package:buchhaltung/services/contact_format.dart';

void main() {
  group('E-Mail', () {
    test('leer und gültig ohne Meldung', () {
      expect(ContactFormat.checkEmail(''), isNull);
      expect(ContactFormat.checkEmail(' office@jenibarb.com '), isNull);
      expect(ContactFormat.checkEmail('a.b+c@sub.beispiel.at'), isNull);
    });
    test('ungültig mit Meldung', () {
      for (final v in [
        'office',
        'office@',
        '@x.at',
        'a@b',
        'a b@x.at',
        'a@x.c',
      ]) {
        expect(ContactFormat.checkEmail(v), isNotNull, reason: v);
      }
    });
  });
  group('Telefon', () {
    test('leer und gültig ohne Meldung', () {
      expect(ContactFormat.checkPhone(''), isNull);
      expect(ContactFormat.checkPhone('+43 660 1234567'), isNull);
      expect(ContactFormat.checkPhone('04242/12345'), isNull);
      expect(ContactFormat.checkPhone('123456'), isNull);
    });
    test('ungültig mit Meldung', () {
      for (final v in ['12345', 'abc123456', '1' * 21, '++43 1234567']) {
        expect(ContactFormat.checkPhone(v), isNotNull, reason: v);
      }
    });
  });
}
