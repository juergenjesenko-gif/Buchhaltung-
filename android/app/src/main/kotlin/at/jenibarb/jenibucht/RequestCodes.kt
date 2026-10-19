package at.jenibarb.jenibucht

/**
 * Alle Request-Codes der App an einer Stelle, jeder genau einmal.
 *
 * Gerätetest 0.22.0 (Pixel): Dokumentenscanner und Sicherungsordner nutzten
 * beide 4711. `MainActivity.onActivityResult` fragt den Sicherungsordner
 * zuerst; der nahm das Scan-Ergebnis an, fand keine offene Antwort und
 * verwarf es still. Folge: Seiten kamen nie in Dart an, das Belegformular
 * blieb leer (0.21.0 zusätzlich: Scanner bis zum Neustart gesperrt).
 */
object RequestCodes {
    const val BACKUP_FOLDER = 4711
    const val BACKUP_FILE = 4712
    const val DOCUMENT_SCANNER = 4721
    const val DICTATION_PERMISSION = 4731
    const val DOCUMENT_PICKER = 4741
}
