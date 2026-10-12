import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../domain/legal_texts.dart';

/// Bestätigungen bei der ersten Einrichtung und nach Textänderungen
/// (Lastenheft L-17.1 bis L-17.4). Jede Bestätigung ist eigenständig, nicht
/// vorausgewählt und nicht überspringbar. Eine Einwilligung in Werbung gibt
/// es nicht, weil die App keine Daten dafür erhebt.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, required this.texts});

  final List<LegalText> texts;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  final _checked = <String>{};
  bool _saving = false;

  bool get _complete => widget.texts.every((t) => _checked.contains(t.kind));

  Future<void> _accept() async {
    setState(() => _saving = true);
    await AppScope.read(context).acceptConsents();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bevor es losgeht'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          for (final text in widget.texts) ...[
            Text(text.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(text.summary),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _checked.contains(text.kind),
              onChanged: (value) => setState(
                () => value == true
                    ? _checked.add(text.kind)
                    : _checked.remove(text.kind),
              ),
              title: Text(text.confirmation),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: _complete && !_saving ? _accept : null,
            child: const Text('Weiter'),
          ),
        ],
      ),
    );
  }
}
