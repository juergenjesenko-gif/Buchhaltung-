import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

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
  static const schemaVersion = 3;

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
    await _seedCategories(db);
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
    ('Bankspesen', 'expense', '4970'),
    ('Sonstige Ausgaben', 'expense', '4900'),
  ];

  static Future<void> _seedCategories(Database db) async {
    final batch = db.batch();
    for (final (name, direction, account) in seedCategories) {
      batch.insert('categories', {
        'name': name,
        'direction': direction,
        'datev_account': account,
        'is_system': 1,
      });
    }
    await batch.commit(noResult: true);
  }
}
