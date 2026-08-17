import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../domain/receipt.dart';
import '../../widgets/common.dart';
import '../onboarding/company_setup_screen.dart';

/// Einstellungen: Stammdaten, Kategorien und die rechtlichen Hinweise.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    final tax = profile?.taxProfile;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
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
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Kategorien'),
                  subtitle: Text('${state.categories.length} Kategorien'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const _CategoryScreen()),
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
            title: 'Daten und Sicherung',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alle Daten liegen ausschließlich auf diesem Gerät. Es gibt keinen '
                  'Server, auf den etwas hochgeladen wird – und damit auch keine '
                  'automatische Sicherung.',
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
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final direction in BookingDirection.values) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                direction == BookingDirection.income ? 'Einnahmen' : 'Ausgaben',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: const Icon(Icons.add),
      ),
    );
  }
}
