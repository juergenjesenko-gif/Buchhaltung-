import 'package:flutter/material.dart';

import '../../app_state.dart';
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

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  BillingPeriod _period = BillingPeriod.month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final license = AppScope.read(context).license;
      if (license.offers == null) license.refresh();
    });
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
                  _ when !license.enabled =>
                    'Testversion: alle Funktionen frei, keine Lizenzprüfung.',
                  Entitlement.pro => 'Pro ist aktiv.',
                  Entitlement.basis => 'Basis ist aktiv.',
                  Entitlement.readOnly =>
                    'Nur lesen: Ansehen, Drucken, Exportieren, Sichern und '
                        'Wiederherstellen gehen weiter. Für neue Buchungen '
                        'brauchst du ein Abo.',
                  Entitlement.none =>
                    'Noch kein Abo. Pro kannst du '
                        '${LicensePolicy.trialDays} Tage kostenlos testen.',
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
              active: entitlement == Entitlement.pro,
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
              active: entitlement == Entitlement.basis,
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
              'Abo-Einstellungen des Stores kündigst. Der kostenlose Test von '
              'Pro (${LicensePolicy.trialDays} Tage, nur beim ersten Abo) geht '
              'danach in das gewählte Abo zum angezeigten Preis über, wenn du '
              'nicht vorher kündigst. Kündigen, Widerruf und Erstattung laufen '
              'über den Store.\n\n'
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
        : '${offer.price} pro $_per';
    final label = active
        ? '$name ist aktiv'
        : pro && !license.record.everSubscribed
        ? '${LicensePolicy.trialDays} Tage kostenlos testen'
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
          if (pro && offer != null && !license.record.everSubscribed)
            Text(
              '${LicensePolicy.trialDays} Tage kostenlos, danach '
              '${offer.price} pro $_per, jederzeit vorher kündbar.',
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
