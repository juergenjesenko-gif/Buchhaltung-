import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'core/formatting.dart';
import 'data/app_database.dart';
import 'data/repositories.dart';
import 'domain/company_profile.dart';
import 'domain/money.dart';
import 'domain/receipt.dart';
import 'services/small_business_monitor.dart';
import 'services/vat_id/vat_check_service.dart';
import 'data/auto_backup_settings.dart';
import 'services/backup/auto_backup_service.dart';
import 'services/backup/backup_service.dart';
import 'services/backup/platform_backup_target.dart';
import 'services/turnover_basis.dart';

/// Anwendungszustand. Bewusst ein einziger [ChangeNotifier] statt eines
/// State-Management-Pakets: der Zustand dieser App ist klein und
/// überschaubar, und jede Abhängigkeit weniger ist eine Abhängigkeit weniger,
/// die vor einem Store-Release aktualisiert werden muss.
class AppState extends ChangeNotifier {
  AppState(this.repositories);

  static Future<AppState> open() async {
    final db = await AppDatabase.instance.database;
    final state = AppState(Repositories(db));
    await state.reload();
    return state;
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

  Future<void> reload() async {
    _profile = await repositories.company.load();
    _categories = await repositories.categories.all();
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
  Future<void> onBookingsChanged() async {
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
  }

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
