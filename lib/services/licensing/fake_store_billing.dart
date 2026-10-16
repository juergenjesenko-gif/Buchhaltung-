import 'dart:async';

import 'license_policy.dart';
import 'store_billing.dart';

/// Store-Ersatz für Tests: Preise, aktive Abos und Erreichbarkeit setzbar.
class FakeStoreBilling implements StoreBilling {
  FakeStoreBilling({
    this.available = true,
    this.online = true,
    Set<String>? active,
    Map<String, String>? prices,
  }) : active = active ?? {},
       prices =
           prices ??
           {
             'basis_monat': '14,90 €',
             'basis_jahr': '142,90 €',
             'pro_monat': '24,90 €',
             'pro_jahr': '238,90 €',
           };

  bool available;
  bool online;
  Set<String> active;
  Map<String, String> prices;
  final bought = <String>[];
  String? lastReplaced;
  final _events = StreamController<PurchaseEvent>.broadcast();

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<StoreOffer>?> loadOffers() async {
    if (!online) return null;
    return [
      for (final p in LicensePolicy.products)
        if (prices[p.id] != null) StoreOffer(product: p, price: prices[p.id]!),
    ];
  }

  @override
  Future<Set<String>?> activeProductIds() async =>
      online ? Set.of(active) : null;

  @override
  Future<void> buy(StoreOffer offer, {String? replacesProductId}) async {
    bought.add(offer.product.id);
    lastReplaced = replacesProductId;
    if (replacesProductId != null) active.remove(replacesProductId);
    active.add(offer.product.id);
    _events.add(
      PurchaseEvent(PurchaseEventKind.purchased, productId: offer.product.id),
    );
  }

  /// Eingelöste Codes; ein Code aus [validCodes] schaltet `pro_monat` frei.
  final redeemed = <String>[];
  Set<String> validCodes = {LicensePolicy.promoCode};

  @override
  Future<bool> redeemCode(String code) async {
    redeemed.add(code);
    if (validCodes.contains(code.trim().toUpperCase())) {
      active.add('pro_monat');
      _events.add(
        const PurchaseEvent(
          PurchaseEventKind.purchased,
          productId: 'pro_monat',
        ),
      );
    }
    return true;
  }

  @override
  Stream<PurchaseEvent> get events => _events.stream;
}
