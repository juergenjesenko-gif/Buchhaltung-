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

  /// Kauf-Ereignisse aus dem Kaufblatt.
  Stream<PurchaseEvent> get events;
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
