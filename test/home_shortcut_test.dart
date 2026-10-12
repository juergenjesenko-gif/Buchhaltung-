import 'package:buchhaltung/services/launcher/home_shortcut_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlatform implements HomeShortcutPlatform {
  _FakePlatform({this.supported = true, this.throws = false});
  final bool supported;
  final bool throws;
  int pins = 0;

  @override
  Future<bool> isSupported() async {
    if (throws) throw Exception('kein Kanal');
    return supported;
  }

  @override
  Future<bool> requestPin() async {
    if (throws) throw Exception('kein Kanal');
    pins++;
    return true;
  }
}

void main() {
  test('FA-1.19: wird genau einmal angeboten', () async {
    final service = HomeShortcutService(
      _FakePlatform(),
      MemoryHomeShortcutFlagStore(),
    );
    expect(await service.shouldOffer(), isTrue);
    await service.markOffered();
    expect(await service.shouldOffer(), isFalse);
  });

  test('FA-1.19: nicht unterstützt -> kein Angebot', () async {
    final service = HomeShortcutService(
      _FakePlatform(supported: false),
      MemoryHomeShortcutFlagStore(),
    );
    expect(await service.isSupported(), isFalse);
    expect(await service.shouldOffer(), isFalse);
  });

  test('FA-1.19: Plattformfehler gilt als nicht unterstützt', () async {
    final service = HomeShortcutService(
      _FakePlatform(throws: true),
      MemoryHomeShortcutFlagStore(),
    );
    expect(await service.shouldOffer(), isFalse);
    expect(await service.requestPin(), isFalse);
  });

  test('FA-1.19: requestPin reicht an die Plattform durch', () async {
    final platform = _FakePlatform();
    final service = HomeShortcutService(
      platform,
      MemoryHomeShortcutFlagStore(),
    );
    expect(await service.requestPin(), isTrue);
    expect(platform.pins, 1);
  });
}
