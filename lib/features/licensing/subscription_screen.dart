import '../../services/licensing/offer_text.dart';
import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/legal_texts.dart';
import '../../services/launcher/open_url.dart';
import '../../services/licensing/in_app_purchase_billing.dart';
import '../../services/licensing/license_policy.dart';
import '../../services/licensing/store_billing.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';
import '../settings/legal_screen.dart';

/// Abo-Seite (L-22.7, L-22.8, Spezifikation FA-12.5): Preise kommen aus dem
/// Store, nie aus dem Code. Vor dem Kauf stehen Laufzeit, automatische
/// Verlängerung, Test mit Folgepreis, Kündigungsweg und die Links zu
/// Nutzungsbedingungen und Datenschutz (Apple Guideline 3.1.2).
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, this.reason});

  /// Warum die Seite aufgeht, z. B. „Belegerkennung gibt es mit Pro.“
  final String? reason;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver {
  BillingPeriod _period = BillingPeriod.month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final license = AppScope.read(context).license;
      if (license.offers == null) license.refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Zurück aus Play Store oder Einlöseblatt: Abo neu abfragen (FA-13.13).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      AppScope.read(context).license.refresh();
    }
  }

  /// Promo-Code einlösen (FA-13.13). iOS: Apples Einlöseblatt mit eigenem
  /// Eingabefeld – ein Tipp. Android: Code eintippen, dann Google Play.
  Future<void> _redeem() async {
    final license = AppScope.read(context).license;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      await license.redeemCode('');
    } else {
      final code = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const PromoCodeSheet(),
      );
      if (code == null || code.trim().isEmpty) return;
      await license.redeemCode(code);
    }
    if (mounted && license.message != null) {
      showSnack(context, license.message!);
    }
  }

  StoreOffer? _offer(List<StoreOffer>? offers, Tier tier) {
    for (final o in offers ?? const <StoreOffer>[]) {
      if (o.product.tier == tier && o.product.period == _period) return o;
    }
    return null;
  }

  String get _per => _period == BillingPeriod.month ? 'Monat' : 'Jahr';

  String get _term =>
      _period == BillingPeriod.month ? 'einen Monat' : 'ein Jahr';

  Future<void> _restore() async {
    final message = await AppScope.read(context).license.restore();
    if (mounted) showSnack(context, message);
  }

  Future<void> _manage() async {
    final apple = Theme.of(context).platform == TargetPlatform.iOS;
    final opened = await openInBrowser(manageSubscriptionsUri(apple: apple));
    if (!opened && mounted) {
      showSnack(
        context,
        apple
            ? 'Einstellungen → dein Name → Abonnements öffnen.'
            : 'Play Store → Profilbild → Zahlungen und Abos → Abos öffnen.',
      );
    }
  }

  void _legal(LegalDocument doc) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => LegalDocumentScreen(document: doc)));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final license = state.license;
    final entitlement = state.entitlement;
    final proIncluded = license.proIncludedUntil;
    final offers = license.offers;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Abo')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (widget.reason != null) ...[
              NoticeBanner(
                icon: Icons.lock_open_outlined,
                message: widget.reason!,
              ),
              const SizedBox(height: 12),
            ],
            SectionCard(
              title: 'Dein Stand',
              child: Text(
                key: const Key('subscription-status'),
                switch (entitlement) {
                  _ when !license.enabled && !state.isDemo =>
                    'Testversion: alle Funktionen frei, keine Lizenzprüfung.',
                  Entitlement.demo
                      when license.entitlement.allows(Feature.newBookings) =>
                    'Du siehst gerade die Demo. Dein Abo '
                        '${license.entitlement.label} ist aktiv.',
                  Entitlement.demo =>
                    'Du siehst gerade die Demo. Mit einem Abo startest du '
                        'mit deinen eigenen Daten – '
                        '${LicensePolicy.trialDays} Tage kostenlos mit allen '
                        'Pro-Funktionen.',
                  Entitlement.pro when proIncluded != null =>
                    'Basis ist aktiv – in der Testzeit mit allen '
                        'Pro-Funktionen bis ${Fmt.date(proIncluded)}. Danach '
                        'gilt Basis, deine Daten bleiben.',
                  Entitlement.pro => 'Pro ist aktiv.',
                  Entitlement.basis => 'Basis ist aktiv.',
                  Entitlement.readOnly =>
                    'Nur lesen: Ansehen, Drucken, Exportieren, Sichern und '
                        'Wiederherstellen gehen weiter. Für neue Buchungen '
                        'brauchst du ein Abo.',
                  Entitlement.none =>
                    'Noch kein Abo. ${LicensePolicy.trialTeaser}',
                },
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<BillingPeriod>(
              key: const Key('subscription-period'),
              style: SegmentedButton.styleFrom(
                minimumSize: const Size(0, PrimaryActionBar.height),
              ),
              segments: const [
                ButtonSegment(
                  value: BillingPeriod.month,
                  label: Text('Monatlich'),
                ),
                ButtonSegment(
                  value: BillingPeriod.year,
                  label: Text('Jährlich'),
                ),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
            const SizedBox(height: 16),
            _tierCard(
              tier: Tier.pro,
              offer: _offer(offers, Tier.pro),
              busy: license.busy,
              active:
                  license.activeTier == Tier.pro &&
                  license.entitlement == Entitlement.pro,
              features: const [
                'Alles aus Basis',
                'Belegerkennung: Betrag, Datum und Händler aus dem Foto',
                'Künftige Pro-Funktionen ohne Aufpreis',
              ],
            ),
            const SizedBox(height: 12),
            _tierCard(
              tier: Tier.basis,
              offer: _offer(offers, Tier.basis),
              busy: license.busy,
              active:
                  license.activeTier == Tier.basis &&
                  license.entitlement.allows(Feature.newBookings),
              features: const [
                'Rechnungen, Belege, Kassabuch, Kunden und Artikel',
                'Übersicht, Kleinunternehmer-Ampel, Steuertermine',
                'Export an die Steuerberatung, Datensicherung',
              ],
            ),
            if (license.message != null) ...[
              const SizedBox(height: 12),
              Text(license.message!, key: const Key('subscription-message')),
            ],
            const SizedBox(height: 16),
            Text(
              key: const Key('subscription-terms'),
              'Preise inkl. USt, abgerechnet über Google Play bzw. den App '
              'Store. Das Abo verlängert sich automatisch um $_term, wenn '
              'du es nicht spätestens 24 Stunden vor Ablauf in den '
              'Abo-Einstellungen des Stores kündigst. Basis und Pro beginnen '
              'mit ${LicensePolicy.trialDays} Tagen kostenlos (nur beim ersten '
              'Abo, laut Store). In dieser Zeit hast du auch mit Basis alle '
              'Pro-Funktionen. Kündigst du in den '
              '${LicensePolicy.trialDays} Tagen, zahlst du nichts; sonst geht '
              'der Test in das gewählte Abo zum angezeigten Preis über. '
              'Kündigen, Widerruf und Erstattung laufen über den Store.\n\n'
              'Deine Daten bleiben immer deine: Ohne Abo kannst du alles '
              'ansehen, drucken, exportieren, sichern und wiederherstellen.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const Key('subscription-restore'),
              leading: const Icon(Icons.restore),
              title: const Text('Kauf wiederherstellen'),
              onTap: license.busy ? null : _restore,
            ),
            ListTile(
              key: const Key('subscription-redeem'),
              leading: const Icon(Icons.redeem_outlined),
              title: const Text('Promo-Code einlösen'),
              subtitle: const Text('Z. B. aus Instagram, über den Store'),
              onTap: license.busy ? null : _redeem,
            ),
            ListTile(
              key: const Key('subscription-manage'),
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Abo verwalten oder kündigen'),
              subtitle: const Text('Öffnet die Abo-Einstellungen des Stores'),
              trailing: const Icon(Icons.open_in_new),
              onTap: _manage,
            ),
            ListTile(
              key: const Key('subscription-terms-link'),
              leading: const Icon(Icons.article_outlined),
              title: Text(LegalDocument.terms.title),
              onTap: () => _legal(LegalDocument.terms),
            ),
            ListTile(
              key: const Key('subscription-privacy-link'),
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(LegalDocument.privacy.title),
              onTap: () => _legal(LegalDocument.privacy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierCard({
    required Tier tier,
    required StoreOffer? offer,
    required bool busy,
    required bool active,
    required List<String> features,
  }) {
    final license = AppScope.read(context).license;
    final pro = tier == Tier.pro;
    final name = pro ? 'Pro' : 'Basis';
    final price = offer == null
        ? (busy
              ? 'Preis wird vom Store geladen …'
              : 'Preis im Store nicht verfügbar')
        // FA-13.15: Phasen aus dem Store (Test, Einführungspreis, Grundpreis).
        : OfferText.priceLine(offer.phases, '${offer.price} pro $_per');
    final summary = offer == null ? null : OfferText.summary(offer.phases);
    final firstTime = !license.record.everSubscribed;
    final label = active
        ? '$name ist aktiv'
        : firstTime
        ? '$name – ${LicensePolicy.trialDays} Tage kostenlos'
        : '$name wählen';
    return SectionCard(
      title: name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            price,
            key: Key('subscription-price-${tier.name}'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (summary != null)
            Text(
              key: Key('subscription-phases-${tier.name}'),
              '$summary'
              '${pro || !firstTime ? '' : ' In den ersten ${LicensePolicy.trialDays} Tagen mit allen Pro-Funktionen, danach Umfang von Basis.'}',
            )
          else if (offer != null && firstTime)
            Text(
              key: Key('subscription-trial-${tier.name}'),
              '${LicensePolicy.trialDays} Tage kostenlos testen – mit allen '
              'Pro-Funktionen. Danach gilt dein gewähltes Abo '
              '(${offer.price} pro $_per). Jederzeit vorher im Store '
              'kündbar.'
              // Befund Prüfinstanz Rechtsanwalt (P-R57): beim Basis-Abo
              // ausdrücklich sagen, dass Pro nur in der Testzeit gilt.
              '${pro ? '' : ' Nach dem Test gilt der Umfang von Basis.'}',
            ),
          const SizedBox(height: 8),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          PrimaryActionBar.filled(
            key: Key('subscription-buy-${tier.name}'),
            label: label,
            icon: pro
                ? Icons.workspace_premium_outlined
                : Icons.check_circle_outline,
            onPressed: offer == null || active || !license.enabled
                ? null
                : () => license.buy(offer),
          ),
        ],
      ),
    );
  }
}

/// Eingabe des Promo-Codes auf Android (FA-13.13): Feld leer, Großbuchstaben,
/// „Einlösen“ in der Daumenzone direkt darunter.
class PromoCodeSheet extends StatefulWidget {
  const PromoCodeSheet({super.key});

  @override
  State<PromoCodeSheet> createState() => _PromoCodeSheetState();
}

class _PromoCodeSheetState extends State<PromoCodeSheet> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_code.text.trim().toUpperCase());

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Promo-Code einlösen',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Google Play öffnet sich und zeigt das Angebot mit Preis danach. '
            'Kündigen kannst du jederzeit vorher im Store.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('promo-code-field'),
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Code'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          PrimaryActionBar.filled(
            key: const Key('promo-code-submit'),
            label: 'Einlösen',
            icon: Icons.redeem_outlined,
            onPressed: _submit,
          ),
        ],
      ),
    ),
  );
}
