import 'domain/fixed_asset.dart';
import 'services/contracts/contract_schedule.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'core/formatting.dart';
import 'data/app_database.dart';
import 'data/repositories.dart';
import 'domain/company_profile.dart';
import 'domain/legal_texts.dart';
import 'domain/money.dart';
import 'domain/country.dart' show EntertainmentRules, MixedUseRules;
import 'domain/receipt.dart';
import 'domain/tax_registration.dart';
import 'services/deadline_calculator.dart';
import 'services/small_business_monitor.dart';
import 'domain/deadline_rule.dart';
import 'services/vat_id/vat_check_service.dart';
import 'data/auto_backup_settings.dart';
import 'services/backup/auto_backup_service.dart';
import 'services/backup/backup_service.dart';
import 'services/backup/platform_backup_target.dart';
import 'services/turnover_basis.dart';
import 'services/app_lock/app_lock_service.dart';
import 'services/app_lock/platform_app_lock.dart';
import 'services/licensing/in_app_purchase_billing.dart';
import 'services/licensing/license_cache.dart';
import 'services/licensing/license_manager.dart';
import 'services/licensing/license_policy.dart';
import 'data/helper_repository.dart';
import 'services/helper/helper_exchange.dart';
import 'services/helper/helper_mail.dart';
import 'services/helper/helper_mail_platform.dart';
import 'services/helper/helper_mail_schedule.dart';
import 'services/helper/helper_mail_sync.dart';
import 'services/helper/helper_package.dart';
import 'services/mail/mail_autoconfig.dart';
import 'services/mail/mail_channel.dart';
import 'services/mail/mail_credentials.dart';
import 'services/mail/mail_server.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show Database;
import 'services/demo/demo_mode.dart';

/// Anwendungszustand. Bewusst ein einziger [ChangeNotifier] statt eines
/// State-Management-Pakets: der Zustand dieser App ist klein und
/// überschaubar, und jede Abhängigkeit weniger ist eine Abhängigkeit weniger,
/// die vor einem Store-Release aktualisiert werden muss.
class AppState extends ChangeNotifier {
  AppState(Repositories repositories, {LicenseManager? license})
    : _realRepositories = repositories,
      _repositories = repositories,
      license =
          license ??
          LicenseManager(
            cache: LicensePolicy.enabled
                ? secureLicenseCache()
                : MemoryLicenseCache(),
            billing: InAppPurchaseBilling.new,
          ) {
    this.license.onChanged = _onLicenseChanged;
  }

  // ---------------------------------------------------------------------
  // Lizenz (L-22.1): Bildschirme fragen nur [allows] bzw. [entitlement].

  final LicenseManager license;

  /// In der Demo immer [Entitlement.demo] (FA-13.14), sonst der Anspruch
  /// aus dem Store – die einzige Quelle für alle Bildschirme.
  Entitlement get entitlement => _demo ? Entitlement.demo : license.entitlement;

  bool allows(Feature feature) => entitlement.allows(feature);

  void _onLicenseChanged() {
    // Abo abgeschlossen, während die Demo vom ersten Start aus lief: Demo
    // verlassen, echte Einrichtung beginnt leer (FA-13.14).
    if (_demo &&
        !_demoFromSettings &&
        license.entitlement.allows(Feature.newBookings)) {
      leaveDemo();
      return;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Demo (FA-13.14, Entscheidung Auftraggeber 2026-10-19, O-42)

  final Repositories _realRepositories;
  Repositories _repositories;
  bool _demo = false;
  bool _demoFromSettings = false;
  Future<void> Function()? _demoCleanup;

  /// Läuft die Demo mit der Muster-Datenbank?
  bool get isDemo => _demo;

  /// Demo über Einstellungen geöffnet (mit Abo oder im Testbuild): Banner
  /// bietet „Demo beenden“ statt „Abo wählen“.
  bool get demoFromSettings => _demoFromSettings;

  /// Öffnet die Muster-Datenbank [demoDb] (siehe `DemoSession.open`) und
  /// zeigt nur noch sie. Die echte Datenbank bleibt unberührt.
  Future<void> enterDemo(
    Database demoDb, {
    bool fromSettings = false,
    Future<void> Function()? onLeave,
  }) async {
    if (_demo) return;
    _demoCleanup = onLeave;
    _isLoading = true;
    notifyListeners();
    await AppDatabase.instance.enterDemo(demoDb);
    DemoMode.active = true;
    _demo = true;
    _demoFromSettings = fromSettings;
    _repositories = Repositories(demoDb);
    await reload();
  }

  /// Zurück zu den echten Daten.
  Future<void> leaveDemo() async {
    if (!_demo) return;
    _isLoading = true;
    notifyListeners();
    _demo = false;
    _demoFromSettings = false;
    DemoMode.active = false;
    _repositories = _realRepositories;
    AppDatabase.instance.leaveDemo();
    final cleanup = _demoCleanup;
    _demoCleanup = null;
    try {
      await cleanup?.call();
    } on Object {
      // Aufräumen ist Komfort; nie die Rückkehr blockieren.
    }
    await reload();
  }

  /// Gespeicherten Stand laden, dann beim Store prüfen (L-22.5).
  Future<void> initLicense() async {
    try {
      await license.init();
    } on Object {
      // Kein Schlüsselbund: Stand bleibt leer, der Store entscheidet.
    }
  }

  static Future<AppState> open() async {
    final db = await AppDatabase.instance.database;
    final state = AppState(Repositories(db));
    await state.reload();
    await state.initAppLock();
    await state.initLicense();
    return state;
  }

  // ---------------------------------------------------------------------
  // App-Sperre (L-22.30, FA-1.13 bis FA-1.18)

  late final AppLockService appLock = AppLockService(
    const SecureAppLockStore(),
  );
  bool _lockEnabled = false;
  bool _locked = false;
  bool _obscured = false;
  int _lockTimeoutSeconds = AppLockPolicy.defaultTimeoutSeconds;
  DateTime? _backgroundSince;

  bool get lockEnabled => _lockEnabled;

  /// Sperrbildschirm zeigen.
  bool get isLocked => _locked;

  /// Inhalt im App-Umschalter abdecken.
  bool get isObscured => _obscured;

  /// Liest die Einstellung; beim Start ist die App gesperrt, wenn aktiv.
  Future<void> initAppLock() async {
    try {
      _lockEnabled = await appLock.isEnabled();
      _lockTimeoutSeconds = await appLock.timeoutSeconds();
    } on Object {
      // Kein Schlüsselbund (Tests): Sperre aus.
      _lockEnabled = false;
    }
    _locked = _lockEnabled;
    await const RecentsPrivacy().hidePreview(_lockEnabled);
    notifyListeners();
  }

  /// Nach Einrichten, Ändern oder Ausschalten.
  Future<void> appLockChanged() async {
    await initAppLock();
    _locked = false;
    notifyListeners();
  }

  /// System-Dialoge (Biometrie, Teilen) machen die App nur inaktiv: abdecken,
  /// aber die Sperrzeit läuft erst ab [onAppHidden].
  void onAppInactive() {
    if (_lockEnabled && !_locked && !_obscured) {
      _obscured = true;
      notifyListeners();
    }
  }

  void onAppHidden() {
    _backgroundSince ??= DateTime.now();
    if (_lockEnabled && !_obscured) {
      _obscured = true;
      notifyListeners();
    }
  }

  void onAppResumed() {
    final since = _backgroundSince;
    _backgroundSince = null;
    if (_lockEnabled &&
        since != null &&
        AppLockPolicy.shouldLockAfterBackground(
          backgroundSince: since,
          now: DateTime.now(),
          timeoutSeconds: _lockTimeoutSeconds,
        )) {
      _locked = true;
    }
    _obscured = false;
    notifyListeners();
  }

  /// Ob es irgendeine Sicherung gibt (von Hand oder automatisch); Grundlage
  /// der Warnung beim Einrichten der Sperre (FA-1.18).
  Future<bool> hasAnyBackup() async {
    if (_profile?.lastBackupAt != null) return true;
    final db = await AppDatabase.instance.database;
    return (await AutoBackupSettings.load(db)).lastAt != null;
  }

  void unlock() {
    _locked = false;
    notifyListeners();
  }

  /// Repositories der laufenden Datenbank: echte Daten oder – in der Demo –
  /// die Muster-Datenbank.
  Repositories get repositories => _repositories;

  late final VatCheckService vatCheckService = VatCheckService(
    repositories.vatChecks,
  );

  bool _vatCheckRunning = false;
  bool _autoBackupRunning = false;
  String? _autoBackupError;

  /// Fehler der letzten automatischen Sicherung; wird auf der Übersicht
  /// angezeigt, damit kein Fehlschlag unbemerkt bleibt (L-7.9).
  String? get autoBackupError => _autoBackupError;

  /// Ergebnis einer von Hand ausgelösten automatischen Sicherung (Einrichten,
  /// „Jetzt sichern“) übernehmen, damit das Banner der Übersicht sofort
  /// verschwindet oder erscheint – nicht erst nach einem Neustart.
  void reportAutoBackupOutcome(AutoBackupOutcome? outcome) {
    if (outcome == null || !outcome.ran) return;
    if (_autoBackupError == outcome.error) return;
    _autoBackupError = outcome.error;
    notifyListeners();
  }

  /// Automatische Sicherung ausgeschaltet: ein alter Fehler ist erledigt.
  void clearAutoBackupError() {
    if (_autoBackupError == null) return;
    _autoBackupError = null;
    notifyListeners();
  }

  /// Dienst der automatischen Sicherung für den gewählten Ordner; `null`,
  /// solange keiner gewählt ist.
  Future<AutoBackupService?> autoBackupService() async {
    final db = await AppDatabase.instance.database;
    final settings = await AutoBackupSettings.load(db);
    final folder = settings.folder;
    if (folder == null) return null;
    return AutoBackupService(
      db: db,
      backups: BackupService(
        db: db,
        documentsDir: await getApplicationDocumentsDirectory(),
        tempDir: await getTemporaryDirectory(),
      ),
      target: PlatformBackupTarget(folder),
      keys: const SecureBackupKeyStore(),
    );
  }

  /// Automatische Sicherung, wenn eingeschaltet und fällig (L-7.2). Läuft
  /// beim Start und bei Rückkehr in die App; Ergebnis und Fehler stehen danach
  /// in den Einstellungen und auf der Übersicht.
  Future<void> runAutoBackupIfDue() async {
    if (_demo || _autoBackupRunning || _profile == null) return;
    _autoBackupRunning = true;
    try {
      final service = await autoBackupService();
      final outcome = await service?.runIfDue();
      if (outcome?.ran ?? false) {
        _autoBackupError = outcome!.error;
        _profile = await repositories.company.load();
        notifyListeners();
      }
    } catch (_) {
      // Fehler speichert der Dienst selbst; hier nichts verschlucken außer
      // dem Fall, dass gar kein Dienst entstehen konnte.
    } finally {
      _autoBackupRunning = false;
    }
  }

  /// Wöchentliche UID-Prüfung, wenn eingeschaltet und fällig. Läuft im
  /// Hintergrund und blockiert nie die Oberfläche; Fehler bleiben folgenlos.
  Future<void> runVatChecksIfDue() async {
    final profile = _profile;
    if (_demo || profile == null || _vatCheckRunning) return;
    if (!profile.vatCheckDue(DateTime.now())) return;
    _vatCheckRunning = true;
    try {
      await vatCheckService.runIfDue(profile);
      _profile = await repositories.company.load();
      notifyListeners();
    } catch (_) {
      // Netz weg o. Ä.: beim nächsten Start erneut.
    } finally {
      _vatCheckRunning = false;
    }
  }

  int _bookingsRevision = 0;

  /// Steigt bei jeder Änderung an Belegen; siehe [onBookingsChanged].
  int get bookingsRevision => _bookingsRevision;

  CompanyProfile? _profile;
  List<ExpenseCategory> _categories = const [];
  SmallBusinessAssessment? _smallBusiness;
  bool _isLoading = true;

  CompanyProfile? get profile => _profile;
  List<ExpenseCategory> get categories => _categories;
  SmallBusinessAssessment? get smallBusiness => _smallBusiness;
  bool get isLoading => _isLoading;

  /// Solange kein Firmenprofil existiert, zeigt die App das Onboarding.
  bool get needsOnboarding =>
      _profile == null || _profile!.companyName.trim().isEmpty;

  List<ExpenseCategory> categoriesFor(BookingDirection direction) =>
      _categories.where((c) => c.direction == direction).toList();

  ExpenseCategory? categoryById(int? id) {
    if (id == null) return null;
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// Noch nicht bestätigte Texte der aktuellen Fassung (L-17.1 bis L-17.4).
  List<LegalText> _missingConsents = const [];
  List<LegalText> get missingConsents => _missingConsents;

  Future<void> acceptConsents() async {
    await repositories.consents.accept(_missingConsents);
    _missingConsents = await repositories.consents.missing();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Mithelfer-Geräte / Belegsammler (FA-17.x)

  HelperLink? _helperLink;

  /// Gesetzt: dieses Gerät ist Mithelfer und zeigt nur die Erfassung.
  HelperLink? get helperLink => _helperLink;
  bool get isHelperDevice => _helperLink != null;

  int _inboxCount = 0;

  /// Offene Belege im Eingang des Hauptgeräts.
  int get inboxCount => _inboxCount;

  Future<void> setHelperLink(HelperLink? link) async {
    await repositories.helpers.saveLink(link);
    _helperLink = link;
    notifyListeners();
    try {
      await configureMailBackground();
    } on Object {
      // Ohne Hintergrund: Senden beim Öffnen der App.
    }
  }

  Future<HelperInbox> helperInbox() async {
    final base = await getApplicationDocumentsDirectory();
    return HelperInbox(
      repositories.helpers,
      pagesDir: Directory(p.join(base.path, 'eingang')),
    );
  }

  /// Ordner „Eingang“ des Hauptgeräts (gemeinsamer Ordner), falls gewählt.
  Future<PlatformBackupTarget?> inboxFolder() async {
    final f = await repositories.helpers.setting('inbox_folder');
    return f == null ? null : PlatformBackupTarget(f);
  }

  /// Gemeinsamen Ordner prüfen (Start, Rückkehr in die App). Nie auf einem
  /// Mithelfer-Gerät. Fehler bleiben still; der Eingang zeigt den Stand.
  Future<void> syncHelperInbox() async {
    if (_demo || isHelperDevice || needsOnboarding) return;
    try {
      final folder = await inboxFolder();
      if (folder != null) await (await helperInbox()).syncFolder(folder);
    } on Object {
      // Ordner nicht erreichbar: beim nächsten Mal wieder.
    }
    await refreshInboxCount();
  }

  // ------------------------------------------------- Mailweg (FA-17.9)

  /// Kennwörter der Postfächer; Tests setzen einen Speicher-Ersatz.
  MailCredentialStore mailCredentials = const SecureMailCredentialStore();

  /// Ersatz-Server für Tests; `null` = echte Verbindung.
  MailConnector? mailConnector;

  /// Serversuche; Tests setzen einen Abruf-Ersatz.
  MailAutoconfig mailAutoconfig = MailAutoconfig();

  /// Letzter Fehler des Mailwegs, für den Hinweis in der Oberfläche.
  MailException? lastMailError;

  Future<HelperMailSync> mailSync({HelperNotifier? notifier}) async =>
      HelperMailSync(
        repositories.helpers,
        documentsDir: await getApplicationDocumentsDirectory(),
        credentials: mailCredentials,
        notifier: notifier,
        connector: mailConnector,
      );

  /// Ein Lauf beim Öffnen der App bzw. bei jeder Rückkehr. Fehler bleiben
  /// still und erscheinen als Hinweis; der nächste Lauf versucht es wieder.
  Future<MailSyncOutcome?> runMailSync({
    MailTrigger trigger = MailTrigger.appOpen,
  }) async {
    // Kein Mailweg in der Demo (FA-13.14).
    if (_demo || (needsOnboarding && !isHelperDevice)) return null;
    try {
      final outcome = await (await mailSync()).run(trigger);
      lastMailError = outcome.error;
      if (outcome.polled) await refreshInboxCount();
      notifyListeners();
      return outcome;
    } on Object {
      return null;
    }
  }

  /// Hintergrundauftrag passend zur Rolle planen (stündlich lesen bzw.
  /// täglich senden) oder entfernen.
  Future<void> configureMailBackground() async {
    if (_demo) return;
    final link = _helperLink;
    String? role;
    if (link != null) {
      role = link.transport == HelperTransport.mail ? 'send' : null;
    } else {
      final settings = await MailReceiveSettings.load(repositories.helpers);
      final password = await mailCredentials.read(MailSlots.receive);
      role = settings.imap != null && (password ?? '').isNotEmpty
          ? 'poll'
          : null;
    }
    await MailBackground.configure(role);
  }

  /// Empfangsadresse für den QR-Code: Geschäfts-E-Mail oder die eigene
  /// Adresse aus „Andere E-Mail-Adresse …“.
  Future<String?> receivingAddress() async {
    final s = await MailReceiveSettings.load(repositories.helpers);
    final a = s.address(_profile?.email ?? '');
    return isMailAddress(a) ? a : null;
  }

  Future<void> refreshInboxCount() async {
    _inboxCount = (await repositories.helpers.inbox()).length;
    notifyListeners();
  }

  Future<void> reload() async {
    // Nach Wiederherstellung einer Sicherung sind alle Belege neu.
    _bookingsRevision++;
    _helperLink = await repositories.helpers.link();
    _setupStep = _demo
        ? null
        : int.tryParse(await repositories.helpers.setting(setupStepKey) ?? '');
    _inboxCount = (await repositories.helpers.inbox()).length;
    _missingConsents = await repositories.consents.missing();
    _profile = await repositories.company.load();
    _smallBusiness = null;
    _deadlines = null;
    _categories = await repositories.categories.all();
    _registrations = await repositories.registrations.all();
    // Vor Schema 11 als bezahlt markierte Rechnungen nachbuchen (L-25.9).
    // Die Muster-Datenbank ist schreibgeschützt und schon vollständig.
    if (!_demo) await repositories.invoices.bookMissingPayments();
    if (_profile != null) {
      Fmt.setCountry(_profile!.country);
      await _refreshSmallBusiness();
    }
    _isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Geführte Ersteinrichtung (FA-1.10, Rückmeldung Auftraggeber 2026-10-19)

  /// Schlüssel in `helper_settings`: Schritt der Ersteinrichtung, an dem die
  /// App nach dem Schließen weitermacht. Fehlt er, ist die Einrichtung
  /// abgeschlossen bzw. (ohne Profil) noch nicht über Schritt 2 hinaus.
  static const setupStepKey = 'setup_step';

  /// Entwurf der Pflichtangaben aus Schritt 2 als JSON, bevor das Profil
  /// gespeichert ist.
  static const setupDraftKey = 'setup_draft';

  int? _setupStep;

  /// Gespeicherter Schritt der Ersteinrichtung (3 bis 5) nach dem
  /// Speichern des Profils; `null` = fertig oder Profil noch nicht angelegt.
  int? get setupStep => _setupStep;

  /// Zeigt die App die Ersteinrichtung? Ohne Profil immer, danach bis zum
  /// letzten Schritt.
  bool get inFirstRunSetup =>
      !_demo && !isHelperDevice && (needsOnboarding || _setupStep != null);

  Future<void> setSetupStep(int? step) async {
    await repositories.helpers.setSetting(setupStepKey, step?.toString());
    _setupStep = step;
    notifyListeners();
  }

  Future<String?> loadSetupDraft() =>
      repositories.helpers.setting(setupDraftKey);

  Future<void> saveSetupDraft(String? json) =>
      repositories.helpers.setSetting(setupDraftKey, json);

  /// Hat diese Installation schon Buchhaltungsdaten? Dann darf sie nicht
  /// zum Mithelfer-Gerät werden (FA-17.13).
  Future<bool> hasBookkeepingData() =>
      repositories.helpers.hasBookkeepingData();

  Future<void> saveProfile(CompanyProfile profile) async {
    await repositories.company.save(profile);
    _profile = profile;
    Fmt.setCountry(profile.country);
    await _refreshSmallBusiness();
    notifyListeners();
  }

  /// Nach jeder Buchung neu bewerten – der Grenzwertmonitor ist nur dann
  /// nützlich, wenn er aktuell ist.
  ///
  /// [bookingsRevision] zählt mit, damit Bildschirme, die im `IndexedStack`
  /// weiterleben (Übersicht), erkennen, dass sie neu laden müssen.
  Future<void> onBookingsChanged() async {
    _bookingsRevision++;
    await _refreshSmallBusiness();
    notifyListeners();
  }

  Future<void> reloadCategories() async {
    _categories = await repositories.categories.all();
    notifyListeners();
  }

  Future<void> _refreshSmallBusiness() async {
    final profile = _profile;
    if (profile == null) return;
    final now = DateTime.now();
    final current = await _yearTurnover(now.year, profile.trackingStart);
    final previous = await _yearTurnover(now.year - 1, profile.trackingStart);
    _smallBusiness = SmallBusinessMonitor.assess(
      taxProfile: profile.taxProfile,
      isSmallBusiness: profile.isSmallBusiness,
      currentYearTurnover: current.amount,
      previousYearTurnover: previous.isComplete ? previous.amount : null,
      currentYearComplete: current.isComplete,
      isFoundingYear: profile.isFoundingYear(now.year),
    );
    // Steuertermine (L-25): Voranmeldungszeitraum aus dem Vorjahr
    // vorschlagen, wenn die Anwenderin nichts gewählt hat. Immer
    // Kalenderjahr, auch bei abweichendem Wirtschaftsjahr (L-24.4).
    final lastYear = await repositories.receipts.totals(
      from: DateTime(now.year - 1, 1, 1),
      to: DateTime(now.year - 1, 12, 31),
    );
    _suggestedInterval = DeadlineCalculator.suggestInterval(
      profile.taxProfile,
      previousYearTurnover: previous.isComplete ? previous.amount : null,
      previousYearVat: lastYear.isEmpty
          ? null
          : lastYear.incomeVat - lastYear.expenseVat,
    );
    _deadlines = DeadlineCalculator.upcoming(
      profile: profile,
      today: now,
      extra: ContractSchedule.deadlines(
        await repositories.contracts.all(),
        now,
      ),
      interval: profile.vatReturnInterval == VatReturnInterval.auto
          ? _suggestedInterval
          : profile.vatReturnInterval,
      registrations: _registrations,
    );
  }

  List<TaxRegistration> _registrations = const [];

  /// Weitere steuerliche Registrierungen (FA-18.x); leer = nur Heimat.
  List<TaxRegistration> get registrations => _registrations;

  /// Registrierung zu einer ID, `null` für Heimat oder unbekannt.
  TaxRegistration? registrationById(int? id) {
    if (id == null) return null;
    for (final r in _registrations) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> saveRegistration(TaxRegistration registration) async {
    await repositories.registrations.save(registration);
    _registrations = await repositories.registrations.all();
    await _refreshSmallBusiness();
    notifyListeners();
  }

  /// `false`, wenn noch Belege darauf gebucht sind.
  Future<bool> deleteRegistration(int id) async {
    final ok = await repositories.registrations.delete(id);
    if (ok) {
      _registrations = await repositories.registrations.all();
      await _refreshSmallBusiness();
      notifyListeners();
    }
    return ok;
  }

  VatReturnInterval _suggestedInterval = VatReturnInterval.quarterly;
  DeadlineOverview? _deadlines;

  /// Vorschlag für den Voranmeldungszeitraum aus dem Vorjahr (L-25.5).
  VatReturnInterval get suggestedVatInterval => _suggestedInterval;

  /// Nächste Steuertermine für die Übersicht (L-25), `null` ohne Profil.
  DeadlineOverview? get deadlines => _deadlines;

  Future<YearTurnover> _yearTurnover(int year, DateTime? trackingStart) async {
    return TurnoverBasis.forYear(
      year: year,
      fromReceipts: await repositories.receipts.turnoverForYear(
        year,
        includeVat: profile!.taxProfile.turnoverIncludesVat,
      ),
      opening: await repositories.openingTurnover.forYear(year),
      trackingStart: trackingStart,
    );
  }

  /// Eröffnungswert eines Jahres, `null` wenn nicht erfasst.
  Future<Money?> openingTurnover(int year) =>
      repositories.openingTurnover.forYear(year);

  /// Speichert Eröffnungswerte und Profil gemeinsam, damit die Ampel danach
  /// sofort auf vollständiger Grundlage bewertet.
  Future<void> saveProfileWithOpenings(
    CompanyProfile profile,
    Map<int, Money?> openings,
  ) async {
    for (final entry in openings.entries) {
      await repositories.openingTurnover.save(entry.key, entry.value);
    }
    await saveProfile(profile);
  }

  /// Der Umsatzsteuersatz, der bei neuen Belegen vorausgewählt wird.
  /// Kleinunternehmer buchen ohne Umsatzsteuer.
  /// Vorsteuerabzug möglich? Kleinunternehmer haben keinen; ihre Ausgaben
  /// zählen brutto (siehe `ReceiptRepository.totals`).
  /// Satz für die Steuer aus Reverse Charge (L-28.4): Normalsatz des Landes.
  int get reverseChargePermille =>
      _profile?.taxProfile.standardVatPermille ?? 0;

  /// Abschreibungsregeln des Landes (FA-15.5), `null` ohne Profil.
  DepreciationRules? get depreciationRules => _profile?.taxProfile.depreciation;

  /// Abzugsbeschränkung Bewirtung des Landes (FA-2.60).
  EntertainmentRules? get entertainmentRules =>
      _profile?.taxProfile.entertainment;

  /// Gemischte Nutzung mit Buchungsregeln (FA-20.3).
  MixedUseRules? get mixedUseRules => _profile?.taxProfile.mixedUse;

  /// Abgabenkategorien ohne Gewinnminderung (FA-19.4).
  Set<String> get nonDeductibleKinds =>
      _profile?.taxProfile.levies.nonDeductibleKinds ?? const {};

  bool get inputVatDeductible => !(_profile?.isSmallBusiness ?? false);

  int get defaultVatPermille {
    final profile = _profile;
    if (profile == null) return 0;
    if (profile.isSmallBusiness) return 0;
    return profile.taxProfile.defaultVatRate.permille;
  }

  Money get currentYearTurnover =>
      _smallBusiness?.currentYearTurnover ?? const Money.zero();
}

/// Stellt den [AppState] im Widget-Baum bereit.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope fehlt im Widget-Baum');
    return scope!.notifier!;
  }

  /// Zugriff ohne Abo – für Aktionen in Callbacks, die kein Rebuild brauchen.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope fehlt im Widget-Baum');
    return scope!.notifier!;
  }
}
