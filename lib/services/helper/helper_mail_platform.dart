import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/app_database.dart';
import '../../data/helper_repository.dart';
import '../mail/mail_credentials.dart';
import 'helper_mail_schedule.dart';
import 'helper_mail_sync.dart';

/// Kennung des Hintergrundauftrags; iOS: in `Info.plist` unter
/// `BGTaskSchedulerPermittedIdentifiers` (FA-17.9).
const mailTaskId = 'at.jesenko.buchhaltung.mailsync';

/// Einstieg für WorkManager (Android) bzw. BGTaskScheduler (iOS). Läuft ohne
/// Oberfläche in einem eigenen Isolate.
@pragma('vm:entry-point')
void mailCallbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      final db = await AppDatabase.instance.database;
      await HelperMailSync(
        HelperRepository(db),
        documentsDir: await getApplicationDocumentsDirectory(),
        credentials: const SecureMailCredentialStore(),
        notifier: LocalHelperNotifier.instance,
      ).run(MailTrigger.background);
    } on Object catch (e) {
      debugPrint('Mailweg im Hintergrund: $e');
    }
    // Immer „erledigt“: ein Fehler wird beim nächsten Lauf neu versucht.
    return true;
  });
}

/// Plant oder beendet den Hintergrundauftrag je nach Rolle.
abstract final class MailBackground {
  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool _initialized = false;

  static Future<void> _init() async {
    if (_initialized) return;
    await Workmanager().initialize(mailCallbackDispatcher);
    _initialized = true;
  }

  /// [role]: `poll` (Hauptgerät stündlich), `send` (Mithelfer täglich) oder
  /// `null` (nichts eingerichtet: Auftrag entfernen).
  static Future<void> configure(String? role) async {
    if (!_supported) return;
    try {
      await _init();
      if (role == null) {
        await Workmanager().cancelByUniqueName(mailTaskId);
        return;
      }
      await Workmanager().registerPeriodicTask(
        mailTaskId,
        role,
        frequency: role == 'poll'
            ? HelperMailSchedule.pollInterval
            : HelperMailSchedule.sendInterval,
        // Nur mit Netz (FA-17.9).
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    } on Object catch (e) {
      // Ohne Hintergrund bleibt der Abruf beim Öffnen der App.
      debugPrint('Hintergrundauftrag nicht geplant: $e');
    }
  }
}

/// Lokale Mitteilung „Belege senden“ (Mithelfer ohne eigenes Postfach).
class LocalHelperNotifier implements HelperNotifier {
  LocalHelperNotifier._();

  static final instance = LocalHelperNotifier._();

  /// Payload beim Antippen: Startseite öffnet das Mailfenster.
  static const sendPayload = 'helper-send';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Wird gesetzt, wenn die Mitteilung angetippt wurde.
  final sendRequested = ValueNotifier<bool>(false);

  Future<void> init() async {
    if (_ready || kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Keine Abfrage beim Start; erst nach der Erklärung (FA-17.9).
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload == sendPayload) sendRequested.value = true;
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true &&
          launch?.notificationResponse?.payload == sendPayload) {
        sendRequested.value = true;
      }
      _ready = true;
    } on Object catch (e) {
      debugPrint('Mitteilungen nicht verfügbar: $e');
    }
  }

  /// Einmalige Abfrage der Berechtigung, nach der Erklärung im Dialog.
  Future<bool> requestPermission() async {
    await init();
    try {
      if (Platform.isAndroid) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;
      }
      if (Platform.isIOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, sound: true) ??
            false;
      }
    } on Object {
      return false;
    }
    return false;
  }

  @override
  Future<void> remindSend(int pending, String businessName) async {
    await init();
    if (!_ready) return;
    await _plugin.show(
      id: 17,
      title: 'Belege senden',
      body:
          '${pending == 1 ? 'Ein Beleg wartet' : '$pending Belege warten'} '
          'für $businessName. Tippen, um sie per Mail zu senden.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'belege_senden',
          'Belege senden',
          channelDescription: 'Erinnerung, gesammelte Belege zu senden',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: sendPayload,
    );
  }
}

/// Mailfenster des Systems mit Anhang (Rückfallweg ohne eigenes Postfach).
abstract final class MailComposer {
  static const _share = MethodChannel('buchhaltung/share_out');
  static const _launcher = MethodChannel('buchhaltung/launcher');

  /// `true`, wenn eine Mail-App geöffnet wurde.
  static Future<bool> compose({
    required String to,
    required String subject,
    required String text,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final dir = await _share.invokeMethod<String>('folder');
        final file = File(p.join(dir!, fileName));
        await file.writeAsBytes(bytes, flush: true);
        return await _share.invokeMethod<bool>('compose', {
              'path': file.path,
              'to': to,
              'subject': subject,
              'text': text,
            }) ??
            false;
      }
      if (Platform.isIOS) {
        final file = File(
          p.join((await getTemporaryDirectory()).path, fileName),
        );
        await file.writeAsBytes(bytes, flush: true);
        final ok = await _launcher.invokeMethod<bool>('composeMail', {
          'path': file.path,
          'to': to,
          'subject': subject,
          'text': text,
        });
        if (ok == true) return true;
        // Kein Mailkonto in Apple Mail: Teilen-Blatt mit Betreff.
        final r = await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/octet-stream')],
          subject: subject,
          text: '$text\n\nAn: $to',
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
        );
        return r.status == ShareResultStatus.success;
      }
    } on Object catch (e) {
      debugPrint('Mailfenster: $e');
    }
    return false;
  }
}
