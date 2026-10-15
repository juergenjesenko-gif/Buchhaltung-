import 'dart:async';

import 'license_cache.dart';
import 'license_policy.dart';
import 'store_billing.dart';

/// Lizenzmanager (L-22.1): liefert nur den [Entitlement]. Kein Server – der
/// Store ist die einzige Quelle; der letzte bestätigte Stand liegt geschützt
/// am Gerät und trägt die App offline [LicensePolicy.offlineGraceDays] Tage.
class LicenseManager {
  LicenseManager({
    required this.cache,
    StoreBilling Function()? billing,
    bool? enabled,
    DateTime Function()? clock,
  }) : _billingFactory = billing,
       enabled = enabled ?? LicensePolicy.enabled,
       _clock = clock ?? DateTime.now;

  final LicenseCache cache;
  final StoreBilling Function()? _billingFactory;
  final DateTime Function() _clock;

  /// `false` in Testbuilds: voller Umfang, kein Store-Zugriff.
  final bool enabled;

  /// Wird nach jeder Änderung des Stands aufgerufen.
  void Function()? onChanged;

  StoreBilling? _billing;
  StreamSubscription<PurchaseEvent>? _events;
  LicenseRecord _record = const LicenseRecord();
  List<StoreOffer>? _offers;
  bool _busy = false;
  String? _message;

  LicenseRecord get record => _record;

  /// Preise aus dem Store; `null`, solange nicht geladen oder offline.
  List<StoreOffer>? get offers => _offers;

  /// Läuft gerade eine Abfrage oder ein Kauf?
  bool get busy => _busy;

  /// Letzte Rückmeldung für die Abo-Seite (z. B. „Kauf abgebrochen“).
  String? get message => _message;

  Entitlement get entitlement =>
      enabled ? LicensePolicy.entitlement(_record, _clock()) : Entitlement.pro;

  bool allows(Feature feature) => entitlement.allows(feature);

  bool get needsOnlineCheck =>
      enabled && LicensePolicy.needsOnlineCheck(_record, _clock());

  DateTime? get trialReminder =>
      enabled ? LicensePolicy.trialReminder(_record, _clock()) : null;

  Tier? get downgradedFrom => enabled ? _record.downgradedFrom : null;

  /// Aktives Produkt, das ein neuer Kauf ersetzt (Wechsel in der Gruppe).
  String? _activeProductId;

  StoreBilling? get _store {
    if (!enabled || _billingFactory == null) return null;
    final store = _billing ??= _billingFactory();
    _events ??= store.events.listen(_onEvent);
    return store;
  }

  /// Gespeicherten Stand laden; danach im Hintergrund beim Store prüfen.
  Future<void> init() async {
    if (!enabled) return;
    _record = await cache.load();
    _notify();
  }

  /// Abfrage beim Store (beim Start, „Kauf wiederherstellen“). Senkt den
  /// Anspruch nur bei einer verlässlichen Antwort des Stores (L-22.5).
  Future<void> refresh() async {
    final store = _store;
    if (store == null || _busy) return;
    _busy = true;
    _message = null;
    _notify();
    try {
      if (!await store.isAvailable()) {
        _message = 'Der Store ist auf diesem Gerät nicht verfügbar.';
        return;
      }
      _offers = await store.loadOffers() ?? _offers;
      final active = await store.activeProductIds();
      if (active == null) {
        _message = 'Store nicht erreichbar. Dein Abo gilt weiter.';
        return;
      }
      final ids = active.where(LicensePolicy.productIds.contains).toSet();
      _activeProductId = _preferred(ids);
      await _saveTier(LicensePolicy.highestTier(ids));
    } on Object {
      _message = 'Store nicht erreichbar. Dein Abo gilt weiter.';
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// „Kauf wiederherstellen“ (L-22.8): Store fragen, Ergebnis melden.
  Future<String> restore() async {
    await refresh();
    if (_message != null) return _message!;
    return switch (entitlement) {
      Entitlement.pro => 'Pro ist aktiv.',
      Entitlement.basis => 'Basis ist aktiv.',
      _ => 'Kein aktives Abo in diesem Store-Konto gefunden.',
    };
  }

  Future<void> buy(StoreOffer offer) async {
    final store = _store;
    if (store == null) return;
    _message = null;
    try {
      await store.buy(
        offer,
        replacesProductId: _activeProductId == offer.product.id
            ? null
            : _activeProductId,
      );
    } on Object {
      _message = 'Der Kauf konnte nicht gestartet werden.';
      _notify();
    }
  }

  /// Hinweis zur Herabstufung gesehen.
  Future<void> acknowledgeDowngrade() async {
    if (_record.downgradedFrom == null) return;
    _record = _record.copyWith(downgradedFrom: () => null);
    await cache.save(_record);
    _notify();
  }

  Future<void> _onEvent(PurchaseEvent event) async {
    switch (event.kind) {
      case PurchaseEventKind.purchased:
        final product = LicensePolicy.product(event.productId ?? '');
        if (product == null) return;
        final now = _clock();
        final firstTrial = !_record.everSubscribed && product.tier == Tier.pro;
        _activeProductId = product.id;
        _record = _record.copyWith(
          tier: () => product.tier,
          checkedAt: now,
          everSubscribed: true,
          trialStartedAt: firstTrial ? () => now : null,
          downgradedFrom: () => null,
        );
        await cache.save(_record);
        _message = '${product.tier == Tier.pro ? 'Pro' : 'Basis'} ist aktiv.';
      case PurchaseEventKind.pending:
        _message =
            'Zahlung ausstehend. Der Store meldet sich, sobald sie '
            'bestätigt ist.';
      case PurchaseEventKind.canceled:
        _message = 'Kauf abgebrochen.';
      case PurchaseEventKind.error:
        _message = event.message ?? 'Der Kauf ist fehlgeschlagen.';
    }
    _notify();
  }

  Future<void> _saveTier(Tier? tier) async {
    final old = _record.tier;
    final lowered = old != null && (tier == null || tier.index < old.index)
        ? old
        : null;
    _record = _record.copyWith(
      tier: () => tier,
      checkedAt: _clock(),
      everSubscribed: _record.everSubscribed || tier != null,
      downgradedFrom: lowered == null ? null : () => lowered,
    );
    await cache.save(_record);
  }

  static String? _preferred(Set<String> ids) {
    String? best;
    for (final id in ids) {
      final tier = LicensePolicy.product(id)!.tier;
      if (best == null ||
          tier.index > LicensePolicy.product(best)!.tier.index) {
        best = id;
      }
    }
    return best;
  }

  void _notify() => onChanged?.call();

  void dispose() => _events?.cancel();
}
