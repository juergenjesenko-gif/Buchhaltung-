import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Logo und App-Symbol (DESIGN_SPEC 10a): alle erzeugten Dateien sind da,
/// erzeugt aus docs/design/logo-final/erzeuge_assets.py.
void main() {
  test('Hauptlogo hell und dunkel in 1x, 2x, 3x', () {
    for (final dir in [
      'assets/brand',
      'assets/brand/2.0x',
      'assets/brand/3.0x',
    ]) {
      for (final name in ['logo.png', 'logo_dark.png']) {
        expect(File('$dir/$name').existsSync(), isTrue, reason: '$dir/$name');
      }
    }
  });

  test('Android-Symbole klassisch, adaptiv, einfarbig, Startbild', () {
    const res = 'android/app/src/main/res';
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      for (final n in [
        'ic_launcher',
        'ic_launcher_foreground',
        'ic_launcher_monochrome',
        'launch_image',
      ]) {
        expect(File('$res/mipmap-$d/$n.png').existsSync(), isTrue, reason: n);
      }
    }
    final xml = File(
      '$res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(xml, contains('<monochrome'));
    expect(
      File('$res/values/colors.xml').readAsStringSync(),
      contains('#0B3A67'),
    );
  });

  test('iOS 1024 ohne Alpha, Store-Dateien und Vektorquelle', () {
    final png = File(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
    ).readAsBytesSync();
    // IHDR: Breite/Höhe ab Byte 16, Farbtyp Byte 25 (2 = RGB ohne Alpha).
    int be(int o) =>
        png[o] << 24 | png[o + 1] << 16 | png[o + 2] << 8 | png[o + 3];
    expect(be(16), 1024);
    expect(be(20), 1024);
    expect(png[25], 2);
    for (final f in [
      'app-icon.svg',
      'play-store-512.png',
      'android-adaptiv-vordergrund-432.png',
      'splash-1152.png',
    ]) {
      expect(File('docs/design/logo-final/$f').existsSync(), isTrue, reason: f);
    }
  });
}
