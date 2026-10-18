import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/receipt.dart' show ExpenseCategory;

/// Lokale SQLite-Datenbank. Offline-first: es gibt keinen Server, die Daten
/// liegen ausschließlich auf dem Gerät des Nutzers.
///
/// Schemaänderungen laufen ausnahmslos über [_migrations]. Jede Migration ist
/// nach ihrer Zielversion benannt und wird genau einmal ausgeführt.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _fileName = 'buchhaltung.db';

  /// Aktuelle Schemaversion. Öffentlich, weil docs/SPECIFICATION.md sie
  /// dokumentiert und test/specification_sync_test.dart beide vergleicht.
  static const schemaVersion = 27;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _fileName);
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: createSchema,
      onUpgrade: upgradeSchema,
    );
  }

  /// Legt das Schema einer neuen Datenbank in der Version [version] an.
  /// Öffentlich, damit Tests es gegen eine In-Memory-Datenbank ausführen
  /// können – Migrationen sind unveränderlich und müssen deshalb vor der
  /// Auslieferung stimmen.
  static Future<void> createSchema(Database db, int version) async {
    await _runMigrations(db, from: 1, to: version);
    await _seedCategories(db, version);
  }

  /// Hebt eine bestehende Datenbank von [oldVersion] auf [newVersion].
  static Future<void> upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) => _runMigrations(db, from: oldVersion + 1, to: newVersion);

  static Future<void> _runMigrations(
    Database db, {
    required int from,
    required int to,
  }) async {
    for (var v = from; v <= to; v++) {
      for (final statement in _migrations[v] ?? const []) {
        await db.execute(statement);
      }
    }
  }

  /// Nur für Tests: erlaubt das Einhängen einer In-Memory-Datenbank.
  // ignore: use_setters_to_change_properties
  void overrideDatabaseForTesting(Database db) => _db = db;

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static const Map<int, List<String>> _migrations = {
    1: [
      '''
      CREATE TABLE company_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        company_name TEXT NOT NULL DEFAULT '',
        owner_name TEXT NOT NULL DEFAULT '',
        country_code TEXT NOT NULL DEFAULT 'AT',
        legal_form TEXT NOT NULL DEFAULT 'soleTrader',
        street TEXT NOT NULL DEFAULT '',
        postal_code TEXT NOT NULL DEFAULT '',
        city TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        website TEXT NOT NULL DEFAULT '',
        tax_number TEXT NOT NULL DEFAULT '',
        vat_id TEXT NOT NULL DEFAULT '',
        is_small_business INTEGER NOT NULL DEFAULT 1,
        iban TEXT NOT NULL DEFAULT '',
        bic TEXT NOT NULL DEFAULT '',
        bank_name TEXT NOT NULL DEFAULT '',
        invoice_number_pattern TEXT NOT NULL DEFAULT 'RE-{YYYY}-{NNNN}',
        next_invoice_sequence INTEGER NOT NULL DEFAULT 1,
        default_payment_term_days INTEGER NOT NULL DEFAULT 14,
        invoice_footer TEXT NOT NULL DEFAULT '',
        fiscal_year_start_month INTEGER NOT NULL DEFAULT 1
      )
      ''',
      '''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        direction TEXT NOT NULL,
        datev_account TEXT,
        is_system INTEGER NOT NULL DEFAULT 0
      )
      ''',
      '''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_person TEXT NOT NULL DEFAULT '',
        street TEXT NOT NULL DEFAULT '',
        postal_code TEXT NOT NULL DEFAULT '',
        city TEXT NOT NULL DEFAULT '',
        country_code TEXT NOT NULL DEFAULT 'AT',
        vat_id TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT ''
      )
      ''',
      '''
      CREATE TABLE receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        direction TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        counterparty TEXT NOT NULL DEFAULT '',
        net_cents INTEGER NOT NULL DEFAULT 0,
        vat_cents INTEGER NOT NULL DEFAULT 0,
        gross_cents INTEGER NOT NULL DEFAULT 0,
        vat_permille INTEGER NOT NULL DEFAULT 0,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        payment_method TEXT NOT NULL DEFAULT 'bank',
        image_path TEXT,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
      'CREATE INDEX idx_receipts_date ON receipts(date)',
      'CREATE INDEX idx_receipts_direction ON receipts(direction)',
      '''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT NOT NULL,
        issue_date TEXT NOT NULL,
        delivery_date TEXT,
        due_date TEXT,
        customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
        status TEXT NOT NULL DEFAULT 'draft',
        is_small_business INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        seller_snapshot TEXT,
        customer_snapshot TEXT,
        paid_at TEXT,
        created_at TEXT NOT NULL
      )
      ''',
      // Eine Rechnungsnummer darf sich nicht wiederholen. Entwürfe tragen eine
      // Platzhalternummer, die beim Ausstellen durch die endgültige ersetzt wird.
      'CREATE UNIQUE INDEX idx_invoices_number ON invoices(number)',
      'CREATE INDEX idx_invoices_issue_date ON invoices(issue_date)',
      '''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        quantity_milli INTEGER NOT NULL DEFAULT 1000,
        unit TEXT NOT NULL DEFAULT 'Stk',
        unit_price_cents INTEGER NOT NULL DEFAULT 0,
        vat_permille INTEGER NOT NULL DEFAULT 0
      )
      ''',
      'CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id)',
      // Nachvollziehbarkeit im Sinne von § 131 BAO (AT) bzw. GoBD (DE):
      // Änderungen an gebuchten Daten werden protokolliert, nicht überschrieben.
      '''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        entity_id INTEGER,
        action TEXT NOT NULL,
        detail TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
      ''',
    ],
    // Version 2: Eröffnungswerte (Lastenheft L-16.1, L-16.2, L-16.11; O-19).
    2: [
      // Umsatz eines Jahres vor Beginn der Erfassung in der App. Ein Eintrag je
      // Jahr. Ohne ihn hielt die Grenzwertüberwachung den Vorjahresumsatz
      // neuer Nutzer für null.
      '''
      CREATE TABLE opening_turnover (
        year INTEGER PRIMARY KEY,
        net_cents INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
      'ALTER TABLE company_profile ADD COLUMN tracking_start TEXT',
      // Bestehende Installationen: als Erfassungsbeginn gilt der älteste Beleg,
      // ohne Belege der Tag der Migration. Damit gilt ein Jahr nur dann als
      // vollständig, wenn die App es tatsächlich ab dem 1. Jänner kennt.
      '''
      UPDATE company_profile
      SET tracking_start = COALESCE((SELECT MIN(date) FROM receipts), date('now'))
      ''',
    ],
    // Version 3: Belegstorno statt Löschen (GoBD, § 131 BAO; Spezifikation 14,
    // P-S10) und Gründungsjahr für die deutsche Grenze im Gründungsjahr
    // (§ 19 Abs 1 UStG; P-S2).
    3: [
      'ALTER TABLE receipts ADD COLUMN cancelled_at TEXT',
      'ALTER TABLE company_profile ADD COLUMN founding_year INTEGER',
    ],
    // Version 4: Zeitpunkt der letzten Datensicherung für die Erinnerung
    // (Lastenheft L-7.4).
    4: ['ALTER TABLE company_profile ADD COLUMN last_backup_at TEXT'],
    // Version 5: Firmenbuch-/Registerangaben (§ 14 UGB, § 37a HGB) und
    // UID-Prüfung über VIES mit Prüfprotokoll als Nachweis.
    5: [
      "ALTER TABLE company_profile ADD COLUMN register_number TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE company_profile ADD COLUMN register_court TEXT NOT NULL DEFAULT ''",
      // Automatische Prüfung nur nach ausdrücklichem Einschalten (Opt-in).
      'ALTER TABLE company_profile ADD COLUMN vat_check_enabled INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE company_profile ADD COLUMN vat_check_last_run TEXT',
      // Nur Einfügen: jede Abfrage bleibt als Nachweis erhalten.
      '''
      CREATE TABLE vat_id_checks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject TEXT NOT NULL,
        subject_id INTEGER,
        vat_id TEXT NOT NULL,
        result TEXT NOT NULL,
        checked_at TEXT NOT NULL,
        name TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        request_identifier TEXT NOT NULL DEFAULT '',
        error_code TEXT NOT NULL DEFAULT ''
      )
      ''',
      'CREATE INDEX idx_vat_id_checks_vat ON vat_id_checks(vat_id, checked_at)',
    ],
    // Version 6: automatische Sicherung in einen gewählten Ordner (L-7.2).
    // Der Ordnerzugriff (SAF-URI bzw. Bookmark) ist kein Geheimnis; der
    // Schlüssel liegt nicht hier, sondern im Schlüsselbund/Keystore.
    6: [
      'ALTER TABLE company_profile ADD COLUMN auto_backup_enabled INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE company_profile ADD COLUMN auto_backup_target TEXT',
      'ALTER TABLE company_profile ADD COLUMN auto_backup_target_label TEXT',
      'ALTER TABLE company_profile ADD COLUMN auto_backup_last_at TEXT',
      'ALTER TABLE company_profile ADD COLUMN auto_backup_last_error TEXT',
    ],
    // Version 7: Bestätigungen bei der ersten Einrichtung mit Zeitpunkt und
    // Textfassung (Lastenheft L-17.1 bis L-17.4). Nur Einfügen.
    7: [
      '''
      CREATE TABLE consents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL,
        version TEXT NOT NULL,
        accepted_at TEXT NOT NULL
      )
      ''',
    ],
    // Version 8: mehrere Seiten je Beleg (L-2.15), Kommentare zu Belegen
    // (L-2.17) und Firmenlogo (L-1.7).
    8: [
      // Fremdschlüssel ohne ON DELETE-Regel: Belege werden nie gelöscht, und
      // die Wiederherstellung einer Sicherung leert die Tabellen mit
      // verzögerter Prüfung (defer_foreign_keys) – RESTRICT wäre sofortig.
      '''
      CREATE TABLE receipt_pages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL REFERENCES receipts(id),
        position INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
      ''',
      'CREATE INDEX idx_receipt_pages_receipt ON receipt_pages(receipt_id, position)',
      // Bestehende Einzelfotos werden zur Seite 1. `receipts.image_path`
      // bleibt als Spiegel der ersten Seite erhalten.
      '''
      INSERT INTO receipt_pages (receipt_id, position, image_path, created_at)
      SELECT id, 1, image_path, COALESCE(updated_at, created_at)
      FROM receipts
      WHERE image_path IS NOT NULL AND image_path != ''
      ''',
      // Nur Einfügen (GoBD, § 131 BAO): Kommentare ergänzen einen Beleg,
      // ohne ihn zu verändern.
      '''
      CREATE TABLE receipt_comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL REFERENCES receipts(id),
        text TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
      ''',
      'CREATE INDEX idx_receipt_comments_receipt ON receipt_comments(receipt_id, created_at)',
      // Ändern verhindert die Datenbank selbst. Löschen nicht, weil die
      // Wiederherstellung einer Sicherung alle Tabellen leeren muss; die App
      // bietet dafür keine Funktion an.
      '''
      CREATE TRIGGER receipt_comments_no_update
      BEFORE UPDATE ON receipt_comments
      BEGIN
        SELECT RAISE(ABORT, 'Kommentare zu Belegen sind unveränderlich');
      END
      ''',
      // Relativer Pfad des Logos im Ordner `logo/` (NFA-4).
      'ALTER TABLE company_profile ADD COLUMN logo_path TEXT',
    ],
    // Version 9: Belege automatisch auslesen (L-2.20 bis L-2.23).
    9: [
      // Abschaltbar in den Einstellungen; neu ist die Erkennung an.
      'ALTER TABLE company_profile ADD COLUMN receipt_scan_enabled INTEGER NOT NULL DEFAULT 1',
      "ALTER TABLE receipts ADD COLUMN document_number TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE receipts ADD COLUMN issuer_vat_id TEXT NOT NULL DEFAULT ''",
      // Fremdwährung nur erkannt und gespeichert, nicht umgerechnet:
      // net/vat/gross bleiben Euro, der Betrag laut Beleg steht daneben.
      "ALTER TABLE receipts ADD COLUMN currency TEXT NOT NULL DEFAULT 'EUR'",
      'ALTER TABLE receipts ADD COLUMN original_gross_cents INTEGER',
    ],
    // Version 10: Fremdwährung umrechnen (L-2.24 bis L-2.26, L-19.29).
    10: [
      // Einheiten der Fremdwährung je 1 Euro × 10^6 (wie die EZB notiert).
      'ALTER TABLE receipts ADD COLUMN fx_rate_micros INTEGER',
      // `YYYY-MM` beim Monatskurs, sonst `YYYY-MM-DD`.
      'ALTER TABLE receipts ADD COLUMN fx_rate_date TEXT',
      // bmf_monthly, ecb_monthly_avg, ecb_daily, manual, bank
      'ALTER TABLE receipts ADD COLUMN fx_rate_source TEXT',
      // Tatsächlich abgebuchter Euro-Betrag; überschreibt den umgerechneten
      // Bruttobetrag nur in der Einnahmen-Ausgaben-Rechnung (L-2.26).
      'ALTER TABLE receipts ADD COLUMN bank_gross_cents INTEGER',
      // Tageskurs nur mit Genehmigung des Finanzamts (L-2.25).
      'ALTER TABLE company_profile ADD COLUMN fx_daily_rate_approved INTEGER NOT NULL DEFAULT 0',
      '''
      CREATE TABLE ecb_rates (
        date TEXT NOT NULL,
        currency TEXT NOT NULL,
        rate_micros INTEGER NOT NULL,
        fetched_at TEXT NOT NULL,
        PRIMARY KEY (date, currency)
      )
      ''',
    ],
    // Version 11: bezahlte Rechnungen als Einnahme (L-25.9), Wirtschaftsjahr
    // (L-24) und Steuertermine (L-25).
    11: [
      // Einnahme aus einer bezahlten Ausgangsrechnung, je Steuersatz eine
      // Zeile. Der eindeutige Index verhindert Doppelbuchungen.
      'ALTER TABLE receipts ADD COLUMN invoice_id INTEGER REFERENCES invoices(id)',
      'CREATE UNIQUE INDEX idx_receipts_invoice ON receipts(invoice_id, vat_permille) '
          'WHERE invoice_id IS NOT NULL',
      // Abweichendes Wirtschaftsjahr bestätigt (L-24.3).
      'ALTER TABLE company_profile ADD COLUMN fiscal_year_confirmed INTEGER NOT NULL DEFAULT 0',
      // Bundesland (nur DE) für Feiertage der Fristberechnung (L-25.4).
      "ALTER TABLE company_profile ADD COLUMN federal_state TEXT NOT NULL DEFAULT ''",
      // auto | monthly | quarterly (L-25.5).
      "ALTER TABLE company_profile ADD COLUMN vat_return_interval TEXT NOT NULL DEFAULT 'auto'",
      'ALTER TABLE company_profile ADD COLUMN vat_permanent_extension INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE company_profile ADD COLUMN files_ecsl INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE company_profile ADD COLUMN has_tax_advisor INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE company_profile ADD COLUMN svs_insured INTEGER NOT NULL DEFAULT 1',
    ],
    // Version 12: Rabatt, Versandkosten, Skonto und AGB-Verweis
    // (L-3.21 bis L-3.26). Bestehende Rechnungen behalten ihre Summen: alle
    // neuen Spalten sind 0 bzw. leer.
    12: [
      // Positionsrabatt: Promille oder Betrag, nie beides.
      'ALTER TABLE invoice_items ADD COLUMN discount_permille INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE invoice_items ADD COLUMN discount_cents INTEGER NOT NULL DEFAULT 0',
      // Gesamtrabatt, Versandkosten (Satz NULL = wie Hauptleistung), Skonto.
      'ALTER TABLE invoices ADD COLUMN discount_permille INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE invoices ADD COLUMN discount_cents INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE invoices ADD COLUMN shipping_cents INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE invoices ADD COLUMN shipping_vat_permille INTEGER',
      'ALTER TABLE invoices ADD COLUMN skonto_days INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE invoices ADD COLUMN skonto_permille INTEGER NOT NULL DEFAULT 0',
      // Beim Zahlungseingang abgezogenes Skonto (Zahlungsvorgang, nicht
      // Rechnungsinhalt – die Rechnung bleibt unverändert).
      'ALTER TABLE invoices ADD COLUMN skonto_taken_cents INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE company_profile ADD COLUMN default_skonto_days INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE company_profile ADD COLUMN default_skonto_permille INTEGER NOT NULL DEFAULT 0',
      "ALTER TABLE company_profile ADD COLUMN terms_url TEXT NOT NULL DEFAULT ''",
      'ALTER TABLE company_profile ADD COLUMN terms_hint_shown INTEGER NOT NULL DEFAULT 0',
    ],
    // Version 13: Mahnwesen (L-3.10, L-3.27 bis L-3.30).
    13: [
      // Unternehmen (B2B) oder Verbraucherin; mit UID vorbelegt Ja.
      'ALTER TABLE customers ADD COLUMN is_business INTEGER NOT NULL DEFAULT 0',
      "UPDATE customers SET is_business = 1 WHERE TRIM(vat_id) != ''",
      // 10,00 EUR je Mahnung (Entscheidung der Auftraggeberin 2026-10-14).
      'ALTER TABLE company_profile ADD COLUMN dunning_fee_cents INTEGER NOT NULL DEFAULT 1000',
      'ALTER TABLE company_profile ADD COLUMN dunning_interest INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE company_profile ADD COLUMN dunning_flat_fee INTEGER NOT NULL DEFAULT 0',
      'ALTER TABLE company_profile ADD COLUMN dunning_period_days INTEGER NOT NULL DEFAULT 14',
      // Momentaufnahme jedes Schreibens; nur Storno mit Begründung.
      '''
      CREATE TABLE dunning_notices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL REFERENCES invoices(id),
        level INTEGER NOT NULL,
        issued_on TEXT NOT NULL,
        new_due_date TEXT NOT NULL,
        principal_cents INTEGER NOT NULL,
        fee_cents INTEGER NOT NULL,
        fees_total_cents INTEGER NOT NULL,
        interest_cents INTEGER NOT NULL,
        interest_rate_bp INTEGER NOT NULL,
        flat_fee_cents INTEGER NOT NULL,
        total_cents INTEGER NOT NULL,
        text TEXT NOT NULL,
        pdf_sha256 TEXT NOT NULL DEFAULT '',
        cancelled_at TEXT,
        cancel_reason TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
      ''',
      'CREATE INDEX idx_dunning_invoice ON dunning_notices(invoice_id, level)',
      // Erlaubt ist nur das einmalige Stornieren mit Begründung.
      '''
      CREATE TRIGGER dunning_notices_immutable
      BEFORE UPDATE ON dunning_notices
      WHEN OLD.cancelled_at IS NOT NULL
        OR NEW.cancelled_at IS NULL
        OR TRIM(NEW.cancel_reason) = ''
        OR NEW.invoice_id IS NOT OLD.invoice_id
        OR NEW.level IS NOT OLD.level
        OR NEW.issued_on IS NOT OLD.issued_on
        OR NEW.new_due_date IS NOT OLD.new_due_date
        OR NEW.total_cents IS NOT OLD.total_cents
        OR NEW.fee_cents IS NOT OLD.fee_cents
        OR NEW.fees_total_cents IS NOT OLD.fees_total_cents
        OR NEW.interest_cents IS NOT OLD.interest_cents
        OR NEW.flat_fee_cents IS NOT OLD.flat_fee_cents
        OR NEW.text IS NOT OLD.text
        OR NEW.pdf_sha256 IS NOT OLD.pdf_sha256
      BEGIN
        SELECT RAISE(ABORT, 'Mahnungen sind unveränderlich; nur Storno mit Begründung');
      END
      ''',
      // Mahnkosten und Zinsen bei Zahlung als nicht umsatzsteuerbare
      // Einnahme, höchstens eine je Rechnung.
      'ALTER TABLE receipts ADD COLUMN dunning_invoice_id INTEGER REFERENCES invoices(id)',
      'CREATE UNIQUE INDEX idx_receipts_dunning ON receipts(dunning_invoice_id) '
          'WHERE dunning_invoice_id IS NOT NULL',
    ],
    // Beleg mit mehreren Steuersätzen (L-2.27): je Satz eine Zeile mit
    // net + vat == gross. Bestehende Belege werden zu genau einer Zeile.
    14: [
      '''
      CREATE TABLE receipt_vat_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        vat_permille INTEGER NOT NULL,
        net_cents INTEGER NOT NULL,
        vat_cents INTEGER NOT NULL,
        gross_cents INTEGER NOT NULL,
        UNIQUE (receipt_id, position)
      )
      ''',
      'CREATE INDEX idx_receipt_vat_lines ON receipt_vat_lines(receipt_id)',
      'INSERT INTO receipt_vat_lines '
          '(receipt_id, position, vat_permille, net_cents, vat_cents, gross_cents) '
          'SELECT id, 1, vat_permille, net_cents, vat_cents, gross_cents '
          'FROM receipts',
    ],
    // Lernspeicher Kassen-ID → Händler (L-27.2): der Kassen-QR enthält keinen
    // Namen; den bestätigten Namen merkt sich die App je Kasse.
    15: [
      '''
      CREATE TABLE cash_register_merchants (
        register_key TEXT PRIMARY KEY,
        merchant TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
    ],
    // Originaldateien (PDF, XML) eines Belegs, unverändert mit SHA-256
    // (L-27.8; § 132 BAO, § 147 AO, GoBD Rz 131 ff.). Nur Einfügen.
    16: [
      '''
      CREATE TABLE receipt_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER NOT NULL REFERENCES receipts(id),
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        mime TEXT NOT NULL,
        sha256 TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        source TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
      ''',
      'CREATE INDEX idx_receipt_documents ON receipt_documents(receipt_id)',
      '''
      CREATE TRIGGER receipt_documents_no_update
      BEFORE UPDATE ON receipt_documents
      BEGIN
        SELECT RAISE(ABORT, 'Originaldateien sind unveränderlich');
      END
      ''',
      '''
      CREATE TRIGGER receipt_documents_no_delete
      BEFORE DELETE ON receipt_documents
      BEGIN
        SELECT RAISE(ABORT, 'Originaldateien werden nicht gelöscht');
      END
      ''',
    ],
    // Plattformimport (L-28.3, L-28.5): Gebühren mit Steuerschuld des
    // Leistungsempfängers und übernommene Zeilen je Plattform. Der
    // Primärschlüssel lässt Dubletten still überspringen (INSERT OR IGNORE).
    17: [
      'ALTER TABLE receipts ADD COLUMN reverse_charge INTEGER NOT NULL DEFAULT 0',
      '''
      CREATE TABLE platform_import_rows (
        platform TEXT NOT NULL,
        external_id TEXT NOT NULL,
        format TEXT NOT NULL,
        month TEXT NOT NULL,
        receipt_id INTEGER REFERENCES receipts(id),
        imported_at TEXT NOT NULL,
        PRIMARY KEY (platform, external_id)
      )
      ''',
      'CREATE INDEX idx_platform_import_month ON platform_import_rows(platform, month)',
    ],
    // Stornorechnung (L-3.7, L-3.18): eigener Beleg mit Bezug auf das
    // Original. Je Originalrechnung höchstens eine Stornorechnung.
    18: [
      'ALTER TABLE invoices ADD COLUMN cancels_invoice_id INTEGER REFERENCES invoices(id)',
      "ALTER TABLE invoices ADD COLUMN cancels_number TEXT NOT NULL DEFAULT ''",
      'ALTER TABLE invoices ADD COLUMN cancels_issue_date TEXT',
      "ALTER TABLE invoices ADD COLUMN cancel_reason TEXT NOT NULL DEFAULT ''",
      'ALTER TABLE invoices ADD COLUMN cancelled_by_invoice_id INTEGER REFERENCES invoices(id)',
      'CREATE UNIQUE INDEX idx_invoices_cancels ON invoices(cancels_invoice_id) '
          'WHERE cancels_invoice_id IS NOT NULL',
    ],
    // Artikelstamm (L-11.1, L-11.2) und Angebote mit eigenem Nummernkreis
    // (L-3.13 bis L-3.17). Angebote buchen nichts (L-3.14).
    19: [
      '''
      CREATE TABLE articles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        unit TEXT NOT NULL DEFAULT 'Stk',
        unit_price_cents INTEGER NOT NULL DEFAULT 0,
        vat_permille INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
      ''',
      'CREATE UNIQUE INDEX idx_articles_number ON articles(number) '
          'WHERE number IS NOT NULL',
      '''
      CREATE TABLE offers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT NOT NULL,
        year INTEGER NOT NULL,
        sequence INTEGER NOT NULL,
        issue_date TEXT NOT NULL,
        valid_until TEXT NOT NULL,
        customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
        status TEXT NOT NULL DEFAULT 'draft',
        is_small_business INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        invoice_id INTEGER REFERENCES invoices(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL
      )
      ''',
      'CREATE UNIQUE INDEX idx_offers_number ON offers(number)',
      'CREATE UNIQUE INDEX idx_offers_sequence ON offers(year, sequence)',
      '''
      CREATE TABLE offer_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        offer_id INTEGER NOT NULL REFERENCES offers(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        quantity_milli INTEGER NOT NULL DEFAULT 1000,
        unit TEXT NOT NULL DEFAULT 'Stk',
        unit_price_cents INTEGER NOT NULL DEFAULT 0,
        vat_permille INTEGER NOT NULL DEFAULT 0,
        discount_permille INTEGER NOT NULL DEFAULT 0,
        discount_cents INTEGER NOT NULL DEFAULT 0
      )
      ''',
      'CREATE INDEX idx_offer_items_offer ON offer_items(offer_id)',
    ],
    // Lernspeicher je Lieferant (FA-2.50): bestätigter Name, Kategorie,
    // Steuersatz, Währung und Zahlungsart je UID bzw. normalisiertem Namen.
    20: [
      '''
      CREATE TABLE supplier_memory (
        supplier_key TEXT PRIMARY KEY,
        counterparty TEXT NOT NULL,
        category_id INTEGER,
        vat_permille INTEGER,
        currency TEXT NOT NULL DEFAULT 'EUR',
        payment_method TEXT,
        updated_at TEXT NOT NULL
      )
      ''',
    ],
    // Anlagevermögen und AfA (FA-15.x, GR-15): Wirtschaftsgüter mit
    // Anschaffungskosten, Nutzungsdauer, Abschreibungsart, Ausscheiden und
    // Kommentaren. Der AfA-Plan wird berechnet, nicht gespeichert.
    21: [
      '''
      CREATE TABLE fixed_assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_id INTEGER REFERENCES receipts(id) ON DELETE SET NULL,
        name TEXT NOT NULL,
        acquired_on TEXT NOT NULL,
        cost_cents INTEGER NOT NULL,
        category_key TEXT NOT NULL,
        useful_life_years INTEGER NOT NULL,
        method TEXT NOT NULL DEFAULT 'linear',
        life_reason TEXT NOT NULL DEFAULT '',
        comment TEXT NOT NULL DEFAULT '',
        disposed_on TEXT,
        disposal_kind TEXT,
        disposal_proceeds_cents INTEGER NOT NULL DEFAULT 0,
        disposal_receipt_id INTEGER REFERENCES receipts(id) ON DELETE SET NULL,
        disposal_comment TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
      'CREATE INDEX idx_fixed_assets_receipt ON fixed_assets(receipt_id)',
    ],
    // Vertragsarchiv (Lastenheft 5.23, FA-16.x): Verträge mit Seiten im
    // Belegspeicher, lokal erkanntem Text und Verknüpfung zu Belegen.
    22: [
      '''
      CREATE TABLE contracts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        partner TEXT NOT NULL DEFAULT '',
        start_date TEXT,
        end_date TEXT,
        notice_value INTEGER,
        notice_unit TEXT NOT NULL DEFAULT 'months',
        rate_cents INTEGER NOT NULL DEFAULT 0,
        rhythm TEXT NOT NULL DEFAULT 'none',
        vat_permille INTEGER NOT NULL DEFAULT 0,
        indexation TEXT NOT NULL DEFAULT '',
        next_index_date TEXT,
        comment TEXT NOT NULL DEFAULT '',
        ocr_text TEXT NOT NULL DEFAULT '',
        original_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE contract_pages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contract_id INTEGER NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        image_path TEXT NOT NULL
      )
      ''',
      'CREATE INDEX idx_contract_pages ON contract_pages(contract_id)',
      '''
      CREATE TABLE contract_receipts (
        contract_id INTEGER NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
        receipt_id INTEGER NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
        PRIMARY KEY (contract_id, receipt_id)
      )
      ''',
    ],
    // Bewirtung mit Abzugsbeschränkung (FA-2.60, Lastenheft 14a): Kennung
    // der Sonderkategorie, Anlass und Teilnehmer am Beleg, Kategorie
    // „Bewirtung“ für bestehende Datenbanken. Eine neue Datenbank ist hier
    // noch leer und erhält die Kategorie über [seedCategories].
    23: [
      'ALTER TABLE categories ADD COLUMN kind TEXT',
      "ALTER TABLE receipts ADD COLUMN entertainment_occasion TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE receipts ADD COLUMN entertainment_participants TEXT NOT NULL DEFAULT ''",
      '''
      INSERT INTO categories (name, direction, datev_account, is_system, kind)
      SELECT 'Bewirtung', 'expense', '4650', 1, 'entertainment'
      WHERE EXISTS (SELECT 1 FROM categories)
        AND NOT EXISTS (SELECT 1 FROM categories WHERE name = 'Bewirtung')
      ''',
      "UPDATE categories SET kind = 'entertainment' WHERE name = 'Bewirtung'",
    ],
    // Mithelfer-Geräte / Belegsammler (Lastenheft 5.29, FA-17.x).
    // Hauptgerät: Kopplungen und Eingang; Mithelfer: eigene Kopplung und
    // gesendete Belege (ohne Bilder). Einstellungen als Schlüssel/Wert.
    24: [
      '''
      CREATE TABLE helper_pairings (
        id TEXT PRIMARY KEY,
        device_name TEXT NOT NULL,
        key_hex TEXT NOT NULL,
        transport TEXT NOT NULL DEFAULT 'share',
        created_at TEXT NOT NULL,
        revoked_at TEXT
      )
      ''',
      '''
      CREATE TABLE helper_inbox (
        uuid TEXT PRIMARY KEY,
        pairing_id TEXT NOT NULL,
        device_name TEXT NOT NULL,
        received_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        reason TEXT NOT NULL DEFAULT '',
        values_json TEXT NOT NULL,
        page_paths TEXT NOT NULL DEFAULT ''
      )
      ''',
      '''
      CREATE TABLE helper_outbox (
        uuid TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        file_name TEXT NOT NULL,
        transport TEXT NOT NULL,
        status TEXT NOT NULL,
        summary TEXT NOT NULL DEFAULT ''
      )
      ''',
      '''
      CREATE TABLE helper_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
      ''',
    ],
    // Startkategorie „Material und Werkzeug“ (Entscheidung Auftraggeberin
    // 2026-10-17, Lastenheft 14a, FA-2.31). SKR03 4985 „Werkzeuge und
    // Kleingeräte“ (SKR04 6845). Nur in bestehende Datenbanken mit
    // Kategorien; neue erhalten sie über [seedCategories].
    25: [
      '''
      INSERT INTO categories (name, direction, datev_account, is_system)
      SELECT 'Material und Werkzeug', 'expense', '4985', 1
      WHERE EXISTS (SELECT 1 FROM categories)
        AND NOT EXISTS (
          SELECT 1 FROM categories WHERE name = 'Material und Werkzeug'
        )
      ''',
    ],
    // Mailweg der Mithelfer-Geräte (FA-17.9, Entscheidung Auftraggeberin
    // 2026-10-17). Hauptgerät: verarbeitete Message-IDs, damit keine Mail
    // doppelt gelesen wird (Mails selbst bleiben unverändert im Postfach).
    // Mithelfer: verschlüsseltes Paket je Beleg und Sendezeitpunkt für die
    // Aufbewahrungsfrist.
    26: [
      '''
      CREATE TABLE helper_mail_seen (
        message_id TEXT PRIMARY KEY,
        seen_at TEXT NOT NULL,
        result TEXT NOT NULL DEFAULT ''
      )
      ''',
      "ALTER TABLE helper_outbox ADD COLUMN sent_at TEXT",
      "ALTER TABLE helper_outbox ADD COLUMN package_path TEXT NOT NULL "
          "DEFAULT ''",
    ],
    // Steuerliche Registrierungen in weiteren Ländern (FA-18.x, Lastenheft
    // L-30, Entscheidung Auftraggeber 2026-10-18): z. B. deutsche
    // USt-Registrierung wegen Amazon-FBA-Lager. Belege tragen ihr Steuerland
    // (NULL = Heimat). OSS-Teilnahme fürs Firmenprofil.
    27: [
      '''
      CREATE TABLE tax_registrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        country_code TEXT NOT NULL,
        vat_id TEXT NOT NULL DEFAULT '',
        tax_number TEXT NOT NULL DEFAULT '',
        tax_office TEXT NOT NULL DEFAULT '',
        scheme TEXT NOT NULL DEFAULT 'standard',
        filing_interval TEXT NOT NULL DEFAULT 'monthly',
        permanent_extension INTEGER NOT NULL DEFAULT 0,
        valid_from TEXT,
        valid_to TEXT
      )
      ''',
      'ALTER TABLE receipts ADD COLUMN tax_registration_id INTEGER '
          'REFERENCES tax_registrations(id)',
      'CREATE INDEX idx_receipts_registration '
          'ON receipts(tax_registration_id)',
      'ALTER TABLE company_profile ADD COLUMN oss_participant INTEGER '
          'NOT NULL DEFAULT 0',
    ],
  };

  /// Startkategorien, damit die App nicht mit einer leeren Auswahlliste startet.
  /// Die Konten folgen SKR03; für Österreich sind sie als Orientierung gedacht
  /// und werden beim Export auf den Einheitskontenrahmen gemappt.
  /// Öffentlich, weil docs/SPECIFICATION.md diese Liste dokumentiert und
  /// test/specification_sync_test.dart beide gegeneinander prüft.
  static const seedCategories = <(String, String, String)>[
    ('Umsatzerlöse', 'income', '8400'),
    ('Erlöse ermäßigter Steuersatz', 'income', '8300'),
    ('Sonstige Einnahmen', 'income', '8500'),
    ('Wareneinkauf', 'expense', '3400'),
    ('Fremdleistungen', 'expense', '3100'),
    ('Büromaterial', 'expense', '4930'),
    ('Telefon & Internet', 'expense', '4920'),
    ('Reisekosten', 'expense', '4670'),
    ('Kfz-Kosten', 'expense', '4530'),
    ('Miete & Betriebskosten', 'expense', '4210'),
    ('Versicherungen', 'expense', '4360'),
    ('Beiträge & Gebühren', 'expense', '4380'),
    ('Fortbildung & Fachliteratur', 'expense', '4945'),
    ('Werbung & Marketing', 'expense', '4600'),
    // SKR03 4650 Bewirtungskosten; Abzugsbeschränkung FA-2.60.
    ('Bewirtung', 'expense', '4650'),
    ('Bankspesen', 'expense', '4970'),
    // SKR03 4985 Werkzeuge und Kleingeräte (SKR04 6845); Baumarkt-Einkauf,
    // FA-2.31. Kontenzuordnung prüft die Kanzlei (P-S66).
    ('Material und Werkzeug', 'expense', '4985'),
    ('Sonstige Ausgaben', 'expense', '4900'),
  ];

  static Future<void> _seedCategories(Database db, int version) async {
    final batch = db.batch();
    for (final (name, direction, account) in seedCategories) {
      batch.insert('categories', {
        'name': name,
        'direction': direction,
        'datev_account': account,
        'is_system': 1,
        // Spalte `kind` gibt es erst ab Schema 23 (Tests legen ältere an).
        if (version >= 23 && name == 'Bewirtung')
          'kind': ExpenseCategory.entertainmentKind,
      });
    }
    await batch.commit(noResult: true);
  }
}
