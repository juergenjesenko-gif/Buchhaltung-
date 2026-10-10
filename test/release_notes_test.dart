import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Jede App-Version braucht einen Eintrag in docs/RELEASE_NOTES.md
/// (CLAUDE.md, Abschnitt „Release Notes"). Wer die Version in pubspec.yaml
/// erhöht, ohne den Eintrag zu schreiben, sieht diesen Test rot.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final notes = File('docs/RELEASE_NOTES.md').readAsStringSync();
  final version = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec)!.group(1)!;

  test('zur Version $version gibt es einen Eintrag', () {
    expect(
      notes,
      contains('\n## $version — '),
      reason: 'docs/RELEASE_NOTES.md braucht "## $version — <Datum>"',
    );
  });

  test('der Eintrag enthält die Felder zur Nachverfolgbarkeit', () {
    final start = notes.indexOf('\n## $version — ');
    final end = notes.indexOf('\n## ', start + 1);
    final entry = notes.substring(start, end == -1 ? notes.length : end);
    for (final field in [
      '| Art |',
      '| Commit |',
      '| Branch |',
      '| Dokumentstände |',
      '| Datenbankschema |',
      '| Prüfung |',
    ]) {
      expect(entry, contains(field), reason: 'Feld $field fehlt');
    }
  });
}
