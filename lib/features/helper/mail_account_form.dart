import 'package:flutter/material.dart';

import '../../services/launcher/open_url.dart';
import '../../services/mail/mail_autoconfig.dart';
import '../../services/mail/mail_server.dart';
import '../../widgets/common.dart';

/// Eingabefelder eines Servers (IMAP oder SMTP). Werden nur gezeigt, wenn die
/// automatische Suche nichts findet oder die Anwenderin sie aufklappt.
class MailServerFields extends StatelessWidget {
  const MailServerFields({
    super.key,
    required this.keyPrefix,
    required this.host,
    required this.port,
    required this.user,
    required this.security,
    required this.onSecurity,
    required this.title,
  });

  final String keyPrefix;
  final TextEditingController host;
  final TextEditingController port;
  final TextEditingController user;
  final MailSecurity security;
  final ValueChanged<MailSecurity> onSecurity;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          key: Key('$keyPrefix-host'),
          controller: host,
          autocorrect: false,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Server'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: Key('$keyPrefix-port'),
                controller: port,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<MailSecurity>(
                key: Key('$keyPrefix-security'),
                initialValue: security,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Verschlüsselung'),
                items: [
                  for (final s in MailSecurity.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) {
                  if (v != null) onSecurity(v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: Key('$keyPrefix-user'),
          controller: user,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Benutzername'),
        ),
      ],
    );
  }
}

/// Nummerierte Anleitung zum App-Passwort mit direktem Link (Gmail, iCloud).
class AppPasswordGuide extends StatelessWidget {
  const AppPasswordGuide({super.key, required this.provider});

  final MailProvider provider;

  @override
  Widget build(BuildContext context) {
    final url = provider.appPasswordUrl;
    final steps = provider.appPasswordSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(switch (provider) {
          MailProvider.gmail => 'Gmail braucht ein App-Passwort',
          MailProvider.icloud => 'iCloud braucht ein App-Passwort',
          MailProvider.other => 'Kennwort oder App-Passwort',
        }, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${i + 1}. ${steps[i]}'),
          ),
        if (url != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('app-password-link'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () async {
              final ok = await openInBrowser(Uri.parse(url));
              if (!ok && context.mounted) showSnack(context, url);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('App-Passwort erstellen'),
          ),
        ],
      ],
    );
  }
}

/// Einmalige Erklärung vor den Berechtigungsabfragen (FA-17.9): Mitteilungen
/// für die Erinnerung und Hintergrundaktualisierung für den Abruf.
Future<bool> explainMailPermissions(
  BuildContext context, {
  required bool helper,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Einmal erlauben'),
        content: Text(
          helper
              ? 'Damit die Belege ohne dein Zutun ankommen:\n\n'
                    '1. Mitteilungen erlauben – die App erinnert dich, falls '
                    'Belege noch nicht gesendet werden konnten.\n'
                    '2. iPhone: Einstellungen → Allgemein → '
                    'Hintergrundaktualisierung für JeNi bucht eingeschaltet '
                    'lassen. Android braucht nichts weiter.\n\n'
                    'Gesendet wird einmal am Tag und bei jedem Öffnen der App.'
              : 'Neue Belege landen von selbst im Eingang: die App sieht '
                    'etwa stündlich und bei jedem Öffnen nach.\n\n'
                    'iPhone: Einstellungen → Allgemein → '
                    'Hintergrundaktualisierung für JeNi bucht eingeschaltet '
                    'lassen. Android braucht nichts weiter.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Später'),
          ),
          FilledButton(
            key: const Key('mail-permissions-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Weiter'),
          ),
        ],
      ),
    ) ??
    false;
