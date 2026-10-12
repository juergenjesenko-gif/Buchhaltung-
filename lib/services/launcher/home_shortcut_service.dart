/// App-Symbol auf dem Startbildschirm (FA-1.19).
///
/// Bei einer Installation per APK legt Android kein Symbol auf den
/// Startbildschirm. Eine App darf es nicht stumm ablegen; zulässig ist nur
/// `ShortcutManager.requestPinShortcut` (Android 8+), das einen Systemdialog
/// zeigt. Dieser Dienst bietet das einmal an und merkt sich, dass gefragt
/// wurde. Auf iOS und anderen Plattformen ist alles ein No-op.
library;

/// Plattformseite: Unterstützung abfragen und Systemdialog anstoßen.
abstract class HomeShortcutPlatform {
  Future<bool> isSupported();

  /// `true`, wenn der Systemdialog angezeigt wurde.
  Future<bool> requestPin();
}

/// Ablage des Merkers „wurde schon gefragt“.
abstract class HomeShortcutFlagStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class MemoryHomeShortcutFlagStore implements HomeShortcutFlagStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class HomeShortcutService {
  HomeShortcutService(this.platform, this.store);

  final HomeShortcutPlatform platform;
  final HomeShortcutFlagStore store;

  static const offeredKey = 'home_shortcut_offered';

  Future<bool> isSupported() async {
    try {
      return await platform.isSupported();
    } catch (_) {
      return false;
    }
  }

  /// Einmaliges Angebot: nur, wenn unterstützt und noch nicht gefragt.
  Future<bool> shouldOffer() async {
    if (await store.read(offeredKey) == '1') return false;
    return isSupported();
  }

  /// Merkt sich, dass gefragt wurde – unabhängig von der Antwort.
  Future<void> markOffered() => store.write(offeredKey, '1');

  Future<bool> requestPin() async {
    try {
      return await platform.requestPin();
    } catch (_) {
      return false;
    }
  }
}
