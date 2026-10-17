/// Zeitentscheidungen des Mailwegs (FA-17.9), reines Dart und ohne Uhr im
/// Inneren, damit Tests jede Lage durchspielen.
library;

/// Was der Mithelfer jetzt tun soll.
enum HelperSendAction {
  /// Nichts offen oder schon erledigt.
  none,

  /// Über das eigene Postfach (SMTP) senden.
  smtp,

  /// Kein Postfach eingerichtet: Erinnerung „Belege senden“ (Mail-App).
  remind,
}

/// Anlass einer Prüfung.
enum MailTrigger {
  /// App geöffnet oder zurückgeholt.
  appOpen,

  /// Hintergrundauftrag des Systems (WorkManager/BGTask).
  background,
}

abstract final class HelperMailSchedule {
  /// Hauptgerät: Abruf stündlich im Hintergrund (Android WorkManager,
  /// Mindestabstand 15 min; iOS bestmöglich).
  static const pollInterval = Duration(hours: 1);

  /// Mithelfer: Versand einmal am Tag im Hintergrund.
  static const sendInterval = Duration(days: 1);

  /// Mindestabstand zweier Abrufe beim Öffnen der App, damit schnelles
  /// Wechseln zwischen Apps das Postfach nicht dauernd anfragt.
  static const openThrottle = Duration(minutes: 2);

  /// Aufbewahrung gesendeter Belege auf dem Mithelfer (Standard,
  /// einstellbar; Entscheidung Auftraggeberin 2026-10-17).
  static const defaultRetentionDays = 90;
  static const retentionChoices = [30, 90, 180, 365];

  /// Hauptgerät: jetzt das Postfach lesen?
  static bool shouldPoll({
    required bool configured,
    required DateTime now,
    required DateTime? lastPoll,
    required MailTrigger trigger,
  }) {
    if (!configured) return false;
    if (lastPoll == null) return true;
    final since = now.difference(lastPoll);
    // Uhr zurückgestellt: lieber einmal mehr lesen.
    if (since.isNegative) return true;
    return switch (trigger) {
      MailTrigger.appOpen => since >= openThrottle,
      // Das System bestimmt den Takt; ein zu früher Lauf liest trotzdem
      // nicht mehr als einmal in 15 Minuten.
      MailTrigger.background => since >= const Duration(minutes: 15),
    };
  }

  /// Mithelfer: senden, erinnern oder nichts.
  static HelperSendAction sendAction({
    required int pending,
    required bool smtpConfigured,
    required DateTime now,
    required DateTime? lastReminder,
    required MailTrigger trigger,
  }) {
    if (pending == 0) return HelperSendAction.none;
    if (smtpConfigured) return HelperSendAction.smtp;
    // Ohne Postfach: höchstens eine Erinnerung am Tag, beim Öffnen der App
    // zeigt die Startseite den Knopf ohnehin.
    if (trigger == MailTrigger.appOpen) return HelperSendAction.none;
    if (lastReminder != null && _sameDay(lastReminder, now)) {
      return HelperSendAction.none;
    }
    return HelperSendAction.remind;
  }

  /// Gesendetes Paket nach [days] Tagen löschen?
  static bool expired({
    required DateTime? sentAt,
    required DateTime now,
    required int days,
  }) => sentAt != null && now.difference(sentAt) >= Duration(days: days);

  /// Laufende Nummer des Pakets am Tag [now], aus dem gespeicherten Stand
  /// `JJJJMMTT:n` (beginnt jeden Tag bei 1).
  static (int seq, String stored) nextSeq(String? stored, String today) {
    if (stored != null) {
      final parts = stored.split(':');
      if (parts.length == 2 && parts[0] == today) {
        final n = (int.tryParse(parts[1]) ?? 0) + 1;
        return (n, '$today:$n');
      }
    }
    return (1, '$today:1');
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
