import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/formatting.dart';
import '../../domain/article.dart';
import '../../domain/money.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_action_bar.dart';

/// Artikelliste (L-11.1, L-11.9). Erreichbar über Rechnungen → Artikel.
class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  List<Article> _articles = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final articles = await AppScope.read(context).repositories.articles.all();
    if (!mounted) return;
    setState(() {
      _articles = articles;
      _loading = false;
    });
  }

  Future<void> _open([Article? article]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ArticleEditScreen(existing: article)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final hits = _articles
        .where(
          (a) =>
              q.isEmpty ||
              a.name.toLowerCase().contains(q) ||
              a.number.toLowerCase().contains(q),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Artikel')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Keine Artikel',
              message:
                  'Lege Waren und Leistungen, die du öfter verrechnest, '
                  'einmal an – danach genügt in Rechnung und Angebot ein '
                  'Tipp. Freie Positionen gehen weiterhin.',
              action: FilledButton.icon(
                onPressed: () => _open(),
                icon: const Icon(Icons.add),
                label: const Text('Artikel anlegen'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (_articles.length > 5)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Suchen (Bezeichnung oder Artikelnummer)',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                for (final a in hits)
                  ListTile(
                    minTileHeight: 56,
                    title: Text(a.name),
                    subtitle: Text(
                      [
                        if (a.number.isNotEmpty) a.number,
                        '${Fmt.money(a.unitPrice)} netto je ${a.unit}',
                        Fmt.vatRate(a.vatPermille),
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(a),
                  ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('article-new'),
        heroTag: 'article-new',
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Neuer Artikel'),
      ),
    );
  }
}

/// Artikel anlegen oder ändern (L-11.1, L-11.2).
class ArticleEditScreen extends StatefulWidget {
  const ArticleEditScreen({super.key, this.existing});

  final Article? existing;

  @override
  State<ArticleEditScreen> createState() => _ArticleEditScreenState();
}

class _ArticleEditScreenState extends State<ArticleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _number = TextEditingController(text: widget.existing?.number);
  late final _description = TextEditingController(
    text: widget.existing?.description,
  );
  late final _unit = TextEditingController(
    text: widget.existing?.unit ?? 'Stk',
  );
  late final _price = TextEditingController(
    text: widget.existing == null ? '' : Fmt.amount(widget.existing!.unitPrice),
  );
  int? _vat;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vat ??=
        widget.existing?.vatPermille ??
        AppScope.read(context).defaultVatPermille;
  }

  @override
  void dispose() {
    for (final c in [_name, _number, _description, _unit, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = AppScope.read(context).repositories.articles;
    if (await repo.numberTaken(_number.text, exceptId: widget.existing?.id)) {
      if (mounted) {
        showSnack(context, 'Die Artikelnummer ist schon vergeben.');
      }
      return;
    }
    setState(() => _saving = true);
    await repo.save(
      Article(
        id: widget.existing?.id,
        number: _number.text.trim(),
        name: _name.text.trim(),
        description: _description.text.trim(),
        unit: _unit.text.trim().isEmpty ? 'Stk' : _unit.text.trim(),
        unitPrice: Money.tryParse(_price.text) ?? const Money.zero(),
        vatPermille: _vat ?? 0,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('„${widget.existing!.name}“ löschen?'),
        content: const Text(
          'Rechnungen und Angebote behalten ihre Positionen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AppScope.read(
      context,
    ).repositories.articles.delete(widget.existing!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tax = state.profile?.taxProfile;
    final rates = tax?.vatRatesOn(DateTime.now(), keep: _vat) ?? const [];
    final small = state.profile?.isSmallBusiness ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Neuer Artikel' : 'Artikel'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('article-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Bezeichnung'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Bitte eine Bezeichnung' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('article-price'),
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'Einzelpreis netto',
                      suffixText: '€',
                    ),
                    validator: (v) {
                      final m = Money.tryParse((v ?? '').trim());
                      if (m == null) return 'Bitte einen Betrag';
                      if (m.isNegative) return 'Nicht negativ';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: TextFormField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: 'Einheit'),
                  ),
                ),
              ],
            ),
            if (!small && rates.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _vat,
                decoration: const InputDecoration(
                  labelText: 'Umsatzsteuersatz',
                ),
                items: [
                  for (final r in rates)
                    DropdownMenuItem(value: r.permille, child: Text(r.display)),
                ],
                onChanged: (v) => setState(() => _vat = v),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _number,
              decoration: const InputDecoration(
                labelText: 'Artikelnummer (freiwillig)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Kurze Beschreibung (freiwillig)',
              ),
              maxLines: 3,
              minLines: 1,
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Artikel löschen'),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: PrimaryActionBar(
        primary: PrimaryActionBar.filled(
          key: const Key('article-save'),
          label: 'Speichern',
          icon: Icons.check,
          busy: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
