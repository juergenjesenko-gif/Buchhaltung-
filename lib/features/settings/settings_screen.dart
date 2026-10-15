import '../licensing/subscription_screen.dart';
import 'legal_screen.dart';
import 'package:flutter/material.dart';

import '../../services/launcher/platform_home_shortcut.dart';
import '../../core/formatting.dart';
import '../app_lock/app_lock_settings_screen.dart';
import '../backup/backup_screen.dart';
import '../../app_state.dart';
import '../../data/app_database.dart';
import '../../data/exchange_rate_repository.dart';
import '../../data/receipt_scan_settings.dart';
import '../../domain/country.dart';
import '../../domain/receipt.dart';
import '../../widgets/common.dart';
import '../onboarding/company_setup_screen.dart';
import '../../widgets/adaptive.dart';
import '../help/help_screen.dart';

/// Einstellungen: Stammdaten, Kategorien und die rechtlichen Hinweise.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    final tax = profile?.taxProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: const [HelpButton()],
      ),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            SectionCard(
              title: 'Stammdaten',
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.business_outlined),
                    title: Text(profile?.companyName ?? 'Nicht gesetzt'),
                    subtitle: Text(
                      [
                        profile?.country.label,
                        profile?.isSmallBusiness == true
                            ? 'Kleinunternehmer'
                            : 'Regelbesteuerung',
                      ].whereType<String>().join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CompanySetupScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.backup_outlined),
                    title: const Text('Datensicherung'),
                    subtitle: Text(
                      profile?.lastBackupAt == null
                          ? 'Noch keine Sicherung'
                          : 'Letzte Sicherung: ${Fmt.date(profile!.lastBackupAt!)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BackupScreen()),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('App-Sperre'),
                    subtitle: Text(
                      state.lockEnabled
                          ? 'Ein – PIN, optional Fingerabdruck/Face ID'
                          : 'Aus',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AppLockSettingsScreen(),
                      ),
                    ),
                  ),
                  const _HomeShortcutTile(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.category_outlined),
                    title: const Text('Kategorien'),
                    subtitle: Text('${state.categories.length} Kategorien'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _CategoryScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (tax != null)
              SectionCard(
                title: 'Rechtlicher Rahmen (${profile!.country.label})',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bullet(
                      context,
                      'Umsatzsteuersätze',
                      tax.vatRates.map((r) => r.display).join(', '),
                    ),
                    _bullet(
                      context,
                      tax.smallBusinessLabel,
                      tax.smallBusinessLegalRef,
                    ),
                    _bullet(
                      context,
                      'Pflichtangaben Rechnung',
                      tax.invoiceLegalRef,
                    ),
                    _bullet(
                      context,
                      'Aufbewahrungsfrist',
                      '${tax.retentionYears} Jahre',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            const SectionCard(
              title: 'Belege auslesen',
              child: _ReceiptScanSwitch(),
            ),
            const SizedBox(height: 16),

            const SectionCard(title: 'Fremdwährung', child: _FxDailySwitch()),
            const SizedBox(height: 16),

            const SectionCard(
              title: 'Daten und Sicherung',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alle Daten liegen auf diesem Gerät. Es gibt keinen Server des '
                    'Anbieters. Sichern kannst du verschlüsselt in deinen eigenen '
                    'Cloud-Ordner – von Hand oder automatisch.',
                  ),
                  SizedBox(height: 10),
                  NoticeBanner(
                    icon: Icons.backup_outlined,
                    message:
                        'Exportiere regelmäßig über den Bereich "Export". '
                        'Geht das Gerät verloren, sind die Belege sonst weg.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: ListTile(
                key: const Key('settings-subscription'),
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Abo'),
                subtitle: Text(
                  state.license.enabled
                      ? state.entitlement.label
                      : 'Testversion – alle Funktionen frei',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                key: const Key('settings-legal'),
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('Rechtliches'),
                subtitle: const Text(
                  'Impressum, Datenschutz, Nutzungsbedingungen, Lizenzen',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LegalScreen())),
              ),
            ),
            const SizedBox(height: 16),

            SectionCard(
              title: 'Wichtiger Hinweis',
              child: Text(
                'Diese App unterstützt bei der Belegerfassung und beim Schreiben von '
                'Rechnungen. Sie ist keine Steuerberatung und keine Registrierkasse '
                'im Sinne der Registrierkassensicherheitsverordnung. Für die '
                'Richtigkeit deiner Buchhaltung und deiner Steuererklärungen bist du '
                'selbst verantwortlich.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(flex: 2, child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

/// Kategorien ansehen, ergänzen und eigene wieder löschen.
class _CategoryScreen extends StatefulWidget {
  const _CategoryScreen();

  @override
  State<_CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<_CategoryScreen> {
  Future<void> _addCategory() async {
    final nameController = TextEditingController();
    final accountController = TextEditingController();
    var direction = BookingDirection.expense;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Neue Kategorie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Bezeichnung'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              SegmentedButton<BookingDirection>(
                segments: const [
                  ButtonSegment(
                    value: BookingDirection.expense,
                    label: Text('Ausgabe'),
                  ),
                  ButtonSegment(
                    value: BookingDirection.income,
                    label: Text('Einnahme'),
                  ),
                ],
                selected: {direction},
                onSelectionChanged: (selection) =>
                    setDialogState(() => direction = selection.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountController,
                decoration: const InputDecoration(
                  labelText: 'Kontonummer (optional)',
                  helperText: 'Für den Export an die Kanzlei',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Anlegen'),
            ),
          ],
        ),
      ),
    );

    if (created == true && nameController.text.trim().isNotEmpty && mounted) {
      final state = AppScope.read(context);
      await state.repositories.categories.insert(
        ExpenseCategory(
          name: nameController.text.trim(),
          direction: direction,
          datevAccount: accountController.text.trim().isEmpty
              ? null
              : accountController.text.trim(),
        ),
      );
      await state.reloadCategories();
    }

    nameController.dispose();
    accountController.dispose();
  }

  Future<void> _delete(ExpenseCategory category) async {
    if (category.isSystem || category.id == null) {
      showSnack(
        context,
        'Vorgegebene Kategorien können nicht gelöscht werden.',
      );
      return;
    }
    final state = AppScope.read(context);
    await state.repositories.categories.delete(category.id!);
    await state.reloadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Kategorien')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final direction in BookingDirection.values) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  direction == BookingDirection.income
                      ? 'Einnahmen'
                      : 'Ausgaben',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              for (final category in state.categoriesFor(direction))
                ListTile(
                  title: Text(category.name),
                  subtitle: category.datevAccount == null
                      ? null
                      : Text('Konto ${category.datevAccount}'),
                  trailing: category.isSystem
                      ? const Icon(Icons.lock_outline, size: 18)
                      : IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(category),
                        ),
                ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Schalter „Belege automatisch auslesen“ (L-2.23).
class _ReceiptScanSwitch extends StatefulWidget {
  const _ReceiptScanSwitch();

  @override
  State<_ReceiptScanSwitch> createState() => _ReceiptScanSwitchState();
}

class _ReceiptScanSwitchState extends State<_ReceiptScanSwitch> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.database.then(ReceiptScanSettings.isEnabled).then((
      value,
    ) {
      if (mounted) setState(() => _enabled = value);
    });
  }

  Future<void> _set(bool value) async {
    setState(() => _enabled = value);
    await ReceiptScanSettings.setEnabled(
      await AppDatabase.instance.database,
      value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _enabled ?? true,
      onChanged: _enabled == null ? null : _set,
      title: const Text('Belege nach dem Fotografieren automatisch auslesen'),
      subtitle: const Text(
        'Datum, Betrag, Steuersatz, Lieferant, UID und Rechnungsnummer werden '
        'auf dem Gerät erkannt und im Formular vorgeschlagen. Du prüfst und '
        'bestätigst beim Speichern. Fotos und Text verlassen das Gerät nicht; '
        'unter Android sendet die Erkennung (Google ML Kit) Nutzungs- und '
        'Diagnosedaten ohne Belegdaten an Google.',
      ),
    );
  }
}

/// Vermerk „Tageskurs vom Finanzamt genehmigt“ (L-2.25).
class _FxDailySwitch extends StatefulWidget {
  const _FxDailySwitch();

  @override
  State<_FxDailySwitch> createState() => _FxDailySwitchState();
}

class _FxDailySwitchState extends State<_FxDailySwitch> {
  bool? _approved;

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.database.then(FxSettings.dailyRateApproved).then((
      value,
    ) {
      if (mounted) setState(() => _approved = value);
    });
  }

  Future<void> _set(bool value) async {
    setState(() => _approved = value);
    await FxSettings.setDailyRateApproved(
      await AppDatabase.instance.database,
      value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tax = AppScope.of(context).profile?.taxProfile ?? TaxProfile.austria;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _approved ?? false,
      onChanged: _approved == null ? null : _set,
      title: const Text('Tageskurs vom Finanzamt genehmigt'),
      subtitle: Text(
        'Für die Umsatzsteuer gilt der Monatskurs (${tax.fxRateLegalRef}). '
        'Nur einschalten, wenn dir das Finanzamt die Umrechnung mit dem '
        'Tageskurs genehmigt hat. „Kurs abrufen“ lädt die EZB-Referenzkurse '
        'nur auf Knopfdruck.',
      ),
    );
  }
}

/// „Symbol auf Startbildschirm legen“ (FA-1.19), nur wenn unterstützt.
class _HomeShortcutTile extends StatefulWidget {
  const _HomeShortcutTile();

  @override
  State<_HomeShortcutTile> createState() => _HomeShortcutTileState();
}

class _HomeShortcutTileState extends State<_HomeShortcutTile> {
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    homeShortcutService.isSupported().then((value) {
      if (mounted) setState(() => _supported = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.add_to_home_screen_outlined),
      title: const Text('Symbol auf Startbildschirm legen'),
      subtitle: const Text('Android fragt zur Bestätigung nach'),
      onTap: homeShortcutService.requestPin,
    );
  }
}
