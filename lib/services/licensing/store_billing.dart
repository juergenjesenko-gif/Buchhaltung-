import 'dart:convert';

import 'license_policy.dart';

/// Schnittstelle zum Store (Google Play Billing, StoreKit). Nur der
/// [LicenseManager] spricht mit ihr; Oberfläche und Funktionen nie (L-22.1).
/// Austauschbar, damit Tests ohne Store laufen ([FakeStoreBilling]).
abstract class StoreBilling {
  /// Ob der Store auf diesem Gerät Käufe zulässt.
  Future<bool> isAvailable();

  /// Angebote mit Preisen **aus dem Store** (nie fest im Code, L-22.7).
  /// `null`, wenn der Store nicht erreichbar ist.
  Future<List<StoreOffer>?> loadOffers();

  /// Produkt-IDs der aktiven Abos; `null`, wenn der Store keine verlässliche
  /// Antwort gibt (offline). Nur eine Antwort ungleich `null` darf den
  /// Anspruch senken.
  Future<Set<String>?> activeProductIds();

  /// Startet das Kaufblatt des Stores. Ein bestehendes Abo der Gruppe wird
  /// ersetzt statt verdoppelt (L-22.2).
  Future<void> buy(StoreOffer offer, {String? replacesProductId});

  /// Promo-Code einlösen (FA-13.13): iOS zeigt das Einlöseblatt von
  /// StoreKit (der Code wird dort eingegeben), Android öffnet die
  /// Einlöse-Adresse von Google Play mit [code]. `false`, wenn nichts
  /// geöffnet werden konnte. Das Ergebnis kommt wie ein Kauf über [events]
  /// bzw. die nächste Abfrage.
  Future<bool> redeemCode(String code);

  /// Testangaben zum aktiven Abo nach der letzten Abfrage bzw. dem letzten
  /// Kauf (O-42): frühester Kaufzeitpunkt und – nur iOS – ob die Transaktion
  /// im Einführungsangebot läuft.
  StoreTrialInfo trialInfo();

  /// Kauf-Ereignisse aus dem Kaufblatt.
  Stream<PurchaseEvent> get events;
}

/// Was der Store zum Test des aktiven Abos verrät (O-42, FA-13.4).
class StoreTrialInfo {
  const StoreTrialInfo({this.firstPurchaseAt, this.introOffer});

  /// Frühester ursprünglicher Kaufzeitpunkt unter den aktiven Abos
  /// (Android `purchaseTime`, iOS `originalPurchaseDate`).
  final DateTime? firstPurchaseAt;

  /// iOS: `true`, wenn StoreKit 2 die Transaktion als Einführungsangebot
  /// meldet; Android: immer `null` (kein Kennzeichen im Client).
  final bool? introOffer;

  static const none = StoreTrialInfo();

  /// Liest die JSON-Darstellung einer StoreKit-2-Transaktion
  /// (`Transaction.jsonRepresentation`, Felder wie im App Store Server API
  /// `JWSTransactionDecodedPayload`): `originalPurchaseDate` in Millisekunden,
  /// `offerType` 1 = Einführungsangebot. Unlesbar → [none].
  static StoreTrialInfo fromAppleTransactionJson(String json) {
    try {
      final map = (jsonDecode(json) as Map).cast<String, Object?>();
      final original = map['originalPurchaseDate'] ?? map['purchaseDate'];
      final offerType = map['offerType'];
      return StoreTrialInfo(
        firstPurchaseAt: original is num
            ? DateTime.fromMillisecondsSinceEpoch(original.round())
            : null,
        introOffer: offerType is num ? offerType == 1 : false,
      );
    } on Object {
      return none;
    }
  }

  /// Zeitstempel in Millisekunden als Text (`PurchaseDetails.transactionDate`,
  /// Android `purchaseTime`); Android meldet kein Testkennzeichen.
  static StoreTrialInfo fromAndroidPurchaseTime(String? millis) {
    final ms = int.tryParse(millis ?? '');
    return StoreTrialInfo(
      firstPurchaseAt: ms == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  /// Fasst mehrere aktive Abos zusammen: frühester Zeitpunkt; im
  /// Einführungsangebot, sobald eines darin läuft.
  static StoreTrialInfo merge(Iterable<StoreTrialInfo> infos) {
    DateTime? first;
    bool? intro;
    for (final i in infos) {
      final at = i.firstPurchaseAt;
      if (at != null && (first == null || at.isBefore(first))) first = at;
      if (i.introOffer != null) intro = (intro ?? false) || i.introOffer!;
    }
    return StoreTrialInfo(firstPurchaseAt: first, introOffer: intro);
  }
}

/// Ein kaufbares Angebot, Preis als vom Store formatierter Text inkl. USt.
class StoreOffer {
  const StoreOffer({required this.product, required this.price, this.handle});

  final LicenseProduct product;

  /// Wiederkehrender Preis je Zeitraum, z. B. „14,90 €“.
  final String price;

  /// Store-eigenes Objekt für den Kauf; nur der Adapter kennt den Typ.
  final Object? handle;
}

enum PurchaseEventKind { purchased, pending, canceled, error }

class PurchaseEvent {
  const PurchaseEvent(this.kind, {this.productId, this.message});

  final PurchaseEventKind kind;
  final String? productId;
  final String? message;
}
