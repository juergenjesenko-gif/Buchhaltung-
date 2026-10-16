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
import 'domain/country.dart' show EntertainmentRules;
import 'domain/receipt.dart';
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

/// Anwendungszustand. Bewusst ein einziger [ChangeNotifier] statt eines
/// State-Management-Pakets: der Zustand dieser App ist klein und
/// überschaubar, und jede Abhängigkeit weniger ist eine Abhängigkeit weniger,
/// die vor einem Store-Release aktualisiert werden muss.
class AppState extends ChangeNotifier {
  AppState(this.repositories, {LicenseManager? license})
    : license =
          license ??
          LicenseManager(
            cache: LicensePolicy.enabled
                ? secureLicenseCache()
                : MemoryLicenseCache(),
            billing: InAppPurchaseBilling.new,
          ) {
    this.license.onChanged = notifyListeners;
  }

  // ---------------------------------------------------------------------
  // Lizenz (L-22.1): Bildschirme fragen nur [allows] bzw. [entitlement].

  final LicenseManager license;

  Entitlement get entitlement => license.entitlement;

  bool allows(Feature feature) => license.allows(feature);

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

  final Repositories repositories;

  late final VatCheckService vatCheckService = VatCheckService(
    repositories.vatChecks,
  );

  bool _vatCheckRunning = false;
  bool _autoBackupRunning = false;
  String? _autoBackupError;

  /// Fehler der letzten automatischen Sicherung; wird auf der Übersicht
  /// angezeigt, damit kein Fehlschlag unbemerkt bleibt (L-7.9).
  String? get autoBackupError => _autoBackupError;

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
    if (_autoBackupRunning || _profile == null) return;
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
    if (profile == null || _vatCheckRunning) return;
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

  Future<void> reload() async {
    // Nach Wiederherstellung einer Sicherung sind alle Belege neu.
    _bookingsRevision++;
    _missingConsents = await repositories.consents.missing();
    _profile = await repositories.company.load();
    _categories = await repositories.categories.all();
    // Vor Schema 11 als bezahlt markierte Rechnungen nachbuchen (L-25.9).
    await repositories.invoices.bookMissingPayments();
    if (_profile != null) {
      Fmt.setCountry(_profile!.country);
      await _refreshSmallBusiness();
    }
    _isLoading = false;
    notifyListeners();
  }

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
    );
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
