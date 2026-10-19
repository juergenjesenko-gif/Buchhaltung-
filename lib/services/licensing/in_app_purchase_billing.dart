import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import '../launcher/open_url.dart';

import 'license_cache.dart';
import 'license_policy.dart';
import 'store_billing.dart';

/// Adapter auf das Paket `in_app_purchase` (Google Play Billing, StoreKit 2;
/// L-22.2). Kaufbelege bleiben beim Store; die App behält nur Produkt und
/// Zeitpunkt der Bestätigung (PRIVACY.md, Lastenheft 5.19).
class InAppPurchaseBilling implements StoreBilling {
  InAppPurchaseBilling();

  /// Wie lange nach „Wiederherstellen“ auf Meldungen des Stores gewartet
  /// wird. StoreKit meldet ein leeres Ergebnis nicht eigens.
  static const restoreWait = Duration(seconds: 6);

  final _iap = InAppPurchase.instance;
  final _events = StreamController<PurchaseEvent>.broadcast();
  final _owned = <String, PurchaseDetails>{};
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Set<String>? _collecting;
  Completer<void>? _firstBatch;

  void _listen() {
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) =>
          _events.add(const PurchaseEvent(PurchaseEventKind.error)),
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    final first = _firstBatch;
    if (first != null && !first.isCompleted) first.complete();
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _owned[p.productID] = p;
          _collecting?.add(p.productID);
          if (p.status == PurchaseStatus.purchased) {
            _events.add(
              PurchaseEvent(
                PurchaseEventKind.purchased,
                productId: p.productID,
              ),
            );
          }
        case PurchaseStatus.pending:
          _events.add(const PurchaseEvent(PurchaseEventKind.pending));
        case PurchaseStatus.canceled:
          _events.add(const PurchaseEvent(PurchaseEventKind.canceled));
        case PurchaseStatus.error:
          _events.add(
            PurchaseEvent(PurchaseEventKind.error, message: p.error?.message),
          );
      }
      // Ohne Abschluss erstattet Google Play den Kauf nach drei Tagen.
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  final _handles = <String, ProductDetails>{};

  @override
  Future<List<StoreOffer>?> loadOffers() async {
    final response = await _iap.queryProductDetails(LicensePolicy.productIds);
    if (response.error != null || response.productDetails.isEmpty) return null;
    final offers = <String, StoreOffer>{};
    for (final details in response.productDetails) {
      final product = LicensePolicy.product(details.id);
      if (product == null) continue;
      var price = details.price;
      var preferTrial = false;
      if (details is GooglePlayProductDetails) {
        // Google liefert je Angebot einen Eintrag; der wiederkehrende Preis
        // ist die letzte Preisphase, ein Test die kostenlose erste.
        final index = details.subscriptionIndex;
        final offer = index == null
            ? null
            : details.productDetails.subscriptionOfferDetails?[index];
        if (offer != null && offer.pricingPhases.isNotEmpty) {
          price = offer.pricingPhases.last.formattedPrice;
          preferTrial = offer.pricingPhases.first.priceAmountMicros == 0;
        }
      }
      final known = offers[product.id];
      if (known == null || preferTrial) {
        offers[product.id] = StoreOffer(
          product: product,
          price: price,
          handle: details,
        );
        _handles[product.id] = details;
      }
    }
    return [
      for (final p in LicensePolicy.products)
        if (offers[p.id] != null) offers[p.id]!,
    ];
  }

  @override
  Future<Set<String>?> activeProductIds() async {
    _listen();
    // Erreichbarkeit belegen: ohne Produktliste keine verlässliche Antwort.
    if (await loadOffers() == null) return null;
    final collected = <String>{};
    _collecting = collected;
    _firstBatch = Completer<void>();
    try {
      await _iap.restorePurchases();
      await Future.any([
        _firstBatch!.future,
        Future<void>.delayed(restoreWait),
      ]);
      await Future<void>.delayed(const Duration(seconds: 1));
      return collected;
    } on Object {
      return null;
    } finally {
      _collecting = null;
    }
  }

  @override
  Future<void> buy(StoreOffer offer, {String? replacesProductId}) async {
    _listen();
    final details = offer.handle is ProductDetails
        ? offer.handle! as ProductDetails
        : _handles[offer.product.id];
    if (details == null) throw StateError('Produkt nicht geladen');
    final old = replacesProductId == null ? null : _owned[replacesProductId];
    final PurchaseParam param = old is GooglePlayPurchaseDetails
        ? GooglePlayPurchaseParam(
            productDetails: details,
            changeSubscriptionParam: ChangeSubscriptionParam(
              oldPurchaseDetails: old,
              replacementMode: ReplacementMode.withTimeProration,
            ),
          )
        // StoreKit: gleiche Abogruppe, der Store wechselt selbst
        // (Upgrade sofort, Downgrade zum Periodenende).
        : PurchaseParam(productDetails: details);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<bool> redeemCode(String code) async {
    _listen();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _iap
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>()
          .presentCodeRedemptionSheet();
      return true;
    }
    return openInBrowser(LicensePolicy.playRedeemUri(code));
  }

  /// Testangaben aus den zuletzt gemeldeten Käufen (O-42): iOS aus der
  /// StoreKit-2-Transaktion (`offerType`, `originalPurchaseDate`), Android nur
  /// der Kaufzeitpunkt (`purchaseTime`).
  @override
  StoreTrialInfo trialInfo() => StoreTrialInfo.merge([
    for (final p in _owned.values)
      if (p is SK2PurchaseDetails || p is AppStorePurchaseDetails)
        StoreTrialInfo.fromAppleTransactionJson(
          p.verificationData.localVerificationData,
        )
      else
        StoreTrialInfo.fromAndroidPurchaseTime(p.transactionDate),
  ]);

  @override
  Stream<PurchaseEvent> get events {
    _listen();
    return _events.stream;
  }
}

/// Lizenzstand im Schlüsselbund (iOS, nur dieses Gerät) bzw. Keystore
/// (Android), L-22.4.
LicenseCache secureLicenseCache() {
  const storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );
  return KeyValueLicenseCache(
    read: (key) => storage.read(key: key),
    write: (key, value) => storage.write(key: key, value: value),
  );
}

/// Direkter Sprung in die Aboverwaltung des Stores (L-22.8).
Uri manageSubscriptionsUri({required bool apple}) => apple
    ? Uri.parse('https://apps.apple.com/account/subscriptions')
    : Uri.parse('https://play.google.com/store/account/subscriptions');
