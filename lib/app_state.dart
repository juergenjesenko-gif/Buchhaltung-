import 'package:flutter/widgets.dart';

import 'core/formatting.dart';
import 'data/app_database.dart';
import 'data/repositories.dart';
import 'domain/company_profile.dart';
import 'domain/money.dart';
import 'domain/receipt.dart';
import 'services/small_business_monitor.dart';

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
    final current = await repositories.receipts.turnoverForYear(now.year);
    final previous = await repositories.receipts.turnoverForYear(now.year - 1);
    _smallBusiness = SmallBusinessMonitor.assess(
      taxProfile: profile.taxProfile,
      isSmallBusiness: profile.isSmallBusiness,
      currentYearTurnover: current,
      previousYearTurnover: previous,
    );
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
