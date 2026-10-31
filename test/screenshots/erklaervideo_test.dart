@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/exchange_rate_repository.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/contract.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/main.dart';
import 'package:buchhaltung/services/demo/demo_dataset.dart';
import 'package:buchhaltung/services/licensing/fake_store_billing.dart';
import 'package:buchhaltung/services/licensing/license_cache.dart';
import 'package:buchhaltung/services/fx/ecb_rates.dart';
import 'package:buchhaltung/services/licensing/license_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Bildschirmaufnahmen für das Erklärvideo (Übergabe Marketing 2026-10-30,
/// Variante B): skriptgesteuertes Bedienen als Widget-Test ohne Emulator,
/// Einzelbilder mit 30 fps, Hochformat 1080×2340.
///
/// Läuft nur mit `ERKLAERVIDEO=1`, siehe `tool/screenshots/README.md`.
/// Ausgabe: `build/erklaervideo/<Aufnahme>/frame_00000.png` …; der Workflow
/// `erklaervideo.yml` setzt sie mit ffmpeg zu `erklaer_<Aufnahme>.mp4`
/// zusammen. `ERKLAERVIDEO_NUR=A1,A7` beschränkt auf einzelne Aufnahmen.
///
/// Was simuliert ist (ehrlich, für die Einblendungen):
/// - Kamera/Scanner: der Systemscanner liefert ein im Code gezeichnetes
///   Demo-Belegbild, die Kameraansicht selbst fehlt.
/// - Texterkennung: der Kanal liefert den Text, der auf dem Demo-Beleg
///   steht; das Auslesen (`ReceiptTextParser`) läuft echt.
/// - Statusleiste und Touch-Anzeige zeichnet nur die Aufnahme.
/// - Die Bildschirmtastatur erscheint nicht; Text wird Zeichen für Zeichen
///   eingesetzt.
void main() {
  final enabled = Platform.environment['ERKLAERVIDEO'] == '1';
  final only = (Platform.environment['ERKLAERVIDEO_NUR'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();

  setUpAll(() async {
    if (!enabled) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('de');
    await _loadFonts();
  });

  void scene(
    String id,
    String title, {
    bool seeded = true,
    bool pro = true,
    bool regular = false,
    required Future<void> Function(_Recorder r) body,
  }) {
    testWidgets('Erklärvideo $id: $title', (tester) async {
      final r = await _Recorder.open(
        tester,
        id,
        seeded: seeded,
        pro: pro,
        regular: regular,
      );
      await body(r);
      await r.close();
    }, skip: !enabled || (only.isNotEmpty && !only.contains(id)));
  }

  // ------------------------------------------------------------------ A1
  scene(
    'A1',
    'Erststart bis Übersicht',
    seeded: false,
    pro: false,
    body: (r) async {
      await r.pause(2);
      await r.tap(find.byKey(const Key('welcome-start')));
      // Schritt 1: Rechtstexte bestätigen.
      await r.tap(find.byKey(const Key('consent-disclaimer')));
      await r.tap(find.byKey(const Key('consent-accept')));
      // Schritt 2: nur der Name ist Pflicht; Österreich ist vorbelegt.
      await r.type(
        find.byKey(const Key('setup-companyName')),
        'Grafikdesign Muster',
      );
      // Im Gründungsjahr fragt die App keinen Vorjahresumsatz.
      await r.type(
        find.byKey(const Key('setup-foundingYear')),
        '${DateTime.now().year}',
      );
      await r.tap(find.byKey(const Key('setup-next')));
      // Schritt 3 und 4: optional.
      await r.tap(find.byKey(const Key('setup-skip')));
      await r.tap(find.byKey(const Key('setup-next')));
      // Schritt 5: Abo später entscheiden.
      await r.tap(find.byKey(const Key('setup-skip')));
      await r.pause(3);
    },
  );

  // ------------------------------------------------------------------ A2
  scene(
    'A2',
    'Beleg fotografieren, Felder füllen sich, speichern',
    body: (r) async {
      await r.pause(2);
      await r.scanReceipt(_Paper.papeterie(DateTime.now()));
      await r.tap(find.byKey(const Key('receipt-save')));
      await r.waitFor(find.byKey(const Key('dashboard-photo')));
      await r.pause(1.5);
      await r.tap(find.text('Belege').last);
      await r.pause(3);
    },
  );

  // ------------------------------------------------------------------ A3
  scene(
    'A3',
    'Slowenischer Beleg (DDV, Skupaj)',
    body: (r) async {
      await r.pause(1.5);
      await r.scanReceipt(_Paper.slovenian(DateTime.now()));
      await r.tap(find.byKey(const Key('receipt-save')));
      await r.waitFor(find.byKey(const Key('dashboard-photo')));
      await r.pause(2);
    },
  );

  // ------------------------------------------------------------------ A4
  scene(
    'A4',
    'Beleg in USD, Kurs abrufen',
    body: (r) async {
      final now = DateTime.now();
      final date = DateTime(now.year, now.month - 1, 15);
      await r.seedRates(date);
      await r.pause(1.5);
      await r.scanReceipt(_Paper.usd(date), browse: false);
      await r.tap(find.textContaining('Kurs abrufen'), after: 2);
      await r.tap(find.byKey(const Key('receipt-save')));
      await r.waitFor(find.byKey(const Key('dashboard-photo')));
      await r.pause(2);
    },
  );

  // ------------------------------------------------------------------ A6
  scene(
    'A6',
    'Vertrag scannen, Kurzübersicht, Rate buchen',
    body: (r) async {
      await r.pause(1.5);
      await r.tap(find.text('Belege').last);
      await r.tap(find.text('Verträge').first);
      await r.tap(find.byKey(const Key('contract-new')));
      final pages = _Paper.lease(DateTime.now());
      await r.prepareScan(pages);
      r.ocrByPage = [for (final page in pages) page.ocr()];
      await r.tap(find.byKey(const Key('contract-photo')));
      await r.pause(1);
      await r.tap(find.byKey(const Key('contract-scan')));
      await r.waitFor(find.text('Kurzübersicht aus dem Text'), seconds: 10);
      await r.pause(1.5);
      for (final label in [
        'Beginn:',
        'Betrag:',
        'Kündigungsfrist:',
        'Wertsicherung:',
      ]) {
        await r.tap(find.textContaining(label).first, after: 0.6);
      }
      await r.type(
        find.widgetWithText(TextFormField, 'Bezeichnung'),
        'Mietvertrag Atelier',
      );
      // Betrag ist übernommen; der Rhythmus steht nicht im Text.
      await r.tap(find.text(PaymentRhythm.none.label));
      await r.tap(find.text(PaymentRhythm.monthly.label).last);
      await r.tap(find.byKey(const Key('contract-save')));
      await r.waitFor(find.text('Mietvertrag Atelier'));
      await r.tap(find.text('Mietvertrag Atelier'));
      await r.tap(find.byKey(const Key('contract-book')));
      await r.tap(find.text('Buchen'));
      await r.waitFor(find.textContaining('verknüpfen (1)'));
      await r.pause(3);
    },
  );

  // ------------------------------------------------------------------ A7
  scene(
    'A7',
    'Übersicht mit Ampel, Beleg buchen, Zahl ändert sich',
    body: (r) async {
      await r.pause(2);
      await r.show(find.text('Kleinunternehmergrenze'));
      await r.pause(2.5);
      await r.scrollToTop();
      await r.pause(1.5);
      await r.scanReceipt(_Paper.office(DateTime.now()), browse: false);
      await r.tap(find.byKey(const Key('receipt-save')));
      await r.waitFor(find.byKey(const Key('dashboard-photo')));
      await r.pause(3);
    },
  );

  // ------------------------------------------------------------------ A8
  scene(
    'A8',
    'Saldenliste (Pro)',
    body: (r) async {
      await r.pause(1.5);
      await r.tap(find.text('Export').last);
      await r.tap(find.byKey(const Key('open-reports')));
      // Vorbelegt ist das Vorjahr; die Musterfirma bucht im laufenden.
      final year = DateTime.now().year;
      await r.tap(find.byType(DropdownButtonFormField<int>));
      await r.tap(find.text('$year').last);
      await r.tap(find.byKey(const Key('report-balance')));
      await r.waitFor(find.byType(Image), seconds: 15);
      await r.pause(4);
    },
  );

  // ------------------------------------------------------------------ A9
  scene(
    'A9',
    'Angebot wird Rechnung, E-Rechnung (ZUGFeRD)',
    body: (r) async {
      await r.pause(1.5);
      await r.tap(find.text('Rechnungen').last);
      await r.tap(find.byKey(const Key('open-offers')));
      await r.tap(find.textContaining('Beispiel Bau').first);
      await r.tap(find.byKey(const Key('offer-convert')));
      // Entwurf ansehen: Positionen, Summe, Pflichtangaben.
      for (var i = 0; i < 2; i++) {
        await r.scrollBy(r.list, 420, seconds: 1.4);
        await r.pause(1.5);
      }
      await r.tap(find.byKey(const Key('invoice-issue')));
      await r.waitFor(find.byKey(const Key('invoice-share')));
      await r.pause(1);
      await r.tap(find.byKey(const Key('invoice-share')));
      await r.waitFor(find.byType(Image), seconds: 15);
      await r.pause(3);
    },
  );

  // ------------------------------------------------------------------ A10
  scene(
    'A10',
    'Kennzahlen für das Finanzamt (Kleinunternehmerin: E1a)',
    body: (r) async {
      await r.pause(1.5);
      await r.tap(find.text('Export').last);
      await r.tap(find.byKey(const Key('open-tax-office')));
      await r.pause(2);
      for (var i = 0; i < 2; i++) {
        await r.scrollBy(r.list, 420, seconds: 1.5);
        await r.pause(2);
      }
      // Eine Kennzahl zum Abschreiben kopieren.
      await r.tap(find.textContaining('Betriebseinnahmen').first, after: 2.5);
    },
  );

  // ------------------------------------------------------------------ A11
  scene(
    'A11',
    'Archiv: älteres Jahr, Aufbewahrungsfrist, Sicherung',
    body: (r) async {
      await r.pause(1.5);
      await r.tap(find.text('Belege').last);
      await r.tap(find.byKey(const Key('receipt-year')));
      await r.tap(find.text('${DateTime.now().year - 1}').last);
      await r.tap(find.byType(ListTile).at(1));
      await r.tap(find.byKey(const Key('receipt-view-edit')));
      await r.show(find.textContaining('Jahre aufzubewahren'));
      await r.pause(3);
      await r.back();
      await r.back();
      await r.tap(find.text('Verträge').first);
      await r.tap(find.textContaining('Mietvertrag').first);
      await r.show(find.textContaining('Aufbewahren'));
      await r.pause(3);
      await r.back();
      await r.back();
      await r.tap(find.text('Übersicht').last);
      await r.tap(find.byTooltip('Einstellungen'));
      await r.tap(find.text('Datensicherung'));
      await r.pause(3);
    },
  );
}

// =====================================================================
// Aufnahme

/// Bedient die App wie eine Person: langsam, jeder Tipp sichtbar, und
/// schreibt dabei jedes Bild (30 fps, fester Zeitschritt).
class _Recorder {
  _Recorder._(this.tester, this.state, this.docs, this.out, this.db);

  static const size = Size(1080, 2340);
  static const ratio = 2.625;
  static const statusBar = 28.0;

  /// Ein Bild alle 33 ms (30 fps mit festem Zeitschritt).
  static const step = Duration(milliseconds: 33);
  static const fps = 30;

  final WidgetTester tester;
  final AppState state;
  final Directory docs;
  final Directory out;
  final Database db;
  final _boundary = GlobalKey();
  final _touch = ValueNotifier<Offset?>(null);
  int _frame = 0;

  Repositories get repos => state.repositories;
  NavigatorState get navigator => appNavigatorKey.currentState!;

  static Future<_Recorder> open(
    WidgetTester tester,
    String id, {
    required bool seeded,
    required bool pro,
    required bool regular,
  }) async {
    final docs = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('erklaervideo'),
    ))!;
    debugDisableShadows = false;
    addTearDown(() {
      debugDisableShadows = true;
      AppDatabase.instance.leaveDemo();
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => docs.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('buchhaltung/share_out'),
      (call) async => true,
    );

    final db = (await tester.runAsync(() async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: AppDatabase.createSchema,
          singleInstance: false,
        ),
      );
      if (seeded) await _seed(db, docs, regular: regular);
      return db;
    }))!;
    AppDatabase.instance.overrideDatabaseForTesting(db);
    final state = AppState(
      Repositories(db),
      license: LicenseManager(
        cache: MemoryLicenseCache(),
        // Grundpreise laut STORE_LISTING „Preise“ (ohne Einführungscode).
        billing: () => FakeStoreBilling(
          active: pro ? {'pro_monat'} : {},
          prices: {
            'basis_monat': '12,90 €',
            'basis_jahr': '129,00 €',
            'pro_monat': '17,90 €',
            'pro_jahr': '179,00 €',
          },
        ),
        enabled: true,
      ),
    );
    await tester.runAsync(state.reload);
    await tester.runAsync(state.license.refresh);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = ratio;
    tester.view.padding = FakeViewPadding(top: statusBar * ratio);
    tester.view.viewPadding = FakeViewPadding(top: statusBar * ratio);
    addTearDown(tester.view.reset);

    final out = Directory(p.join('build', 'erklaervideo', id));
    await tester.runAsync(() async {
      if (await out.exists()) await out.delete(recursive: true);
      await out.create(recursive: true);
    });
    final r = _Recorder._(tester, state, docs, out, db);
    r._mockPlatform(messenger);
    await tester.pumpWidget(r._root());
    await r._load();
    return r;
  }

  Widget _root() => RepaintBoundary(
    key: _boundary,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          BuchhaltungApp(state: state),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: statusBar,
            child: IgnorePointer(child: _StatusBar()),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<Offset?>(
                valueListenable: _touch,
                builder: (context, at, _) =>
                    CustomPaint(painter: _TouchPainter(at)),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// Laden vor der ersten Aufnahme (Datenbank, Bilder), ohne Bilder.
  Future<void> _load() async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(step);
    }
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
    debugDisableShadows = true;
    await tester.runAsync(() => docs.delete(recursive: true));
  }

  // ---------------------------------------------------------------- Bilder

  /// Ein Bild: Uhr um 33 ms weiter, echte Wartezeit für Datenbank und
  /// Bilddekodierung, dann als PNG schreiben.
  Future<void> frame() async {
    await tester.pump(step);
    final render =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final file = File(
      p.join(out.path, 'frame_${(_frame++).toString().padLeft(5, '0')}.png'),
    );
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: ratio);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await file.writeAsBytes(png!.buffer.asUint8List());
    });
  }

  Future<void> frames(int count) async {
    for (var i = 0; i < count; i++) {
      await frame();
    }
  }

  /// Ruhe von [seconds] Sekunden.
  Future<void> pause([double seconds = 1]) => frames((seconds * fps).round());

  // ------------------------------------------------------------ Bedienung

  /// Langsamer Tipp: 1 s Ruhe, Finger sichtbar ~0,3 s, Tipp, 1 s Ruhe.
  /// Liegt das Ziel weiter unten in der Liste, wird dorthin gewischt.
  Future<void> tap(Finder target, {double after = 1}) async {
    await waitFor(target, searchBelow: true);
    await reveal(target);
    await pause(1);
    final at = tester.getCenter(target.first);
    _touch.value = at;
    await frames(5);
    await tester.tapAt(at);
    await frames(5);
    _touch.value = null;
    await pause(after);
  }

  /// Gibt es [target]? (`.first` auf leerem Finder wirft.)
  bool present(Finder target) {
    try {
      return target.evaluate().isNotEmpty;
    } on StateError {
      return false;
    }
  }

  /// Bilder aufnehmen, bis [target] da ist (Laden, Übergang), höchstens
  /// [seconds] Sekunden. [searchBelow]: fehlt es nach 1,5 s noch, liegt
  /// es wohl unten in einer noch nicht gebauten Liste – hinwischen.
  Future<void> waitFor(
    Finder target, {
    double seconds = 8,
    bool searchBelow = false,
  }) async {
    for (var i = 0; i < seconds * fps; i++) {
      if (present(target)) return;
      if (searchBelow && i >= 45 && i % 15 == 0 && present(list)) {
        final position = tester.state<ScrollableState>(list).position;
        if (position.pixels < position.maxScrollExtent) {
          await scrollBy(list, 300, seconds: 0.7);
          continue;
        }
      }
      await frame();
    }
    throw StateError(
      'Nicht erschienen: ${target.toString(describeSelf: true)}',
    );
  }

  /// Feld antippen und [text] Zeichen für Zeichen eingeben.
  Future<void> type(Finder field, String text) async {
    await tap(field, after: 0.3);
    await tester.showKeyboard(field.first);
    for (var i = 1; i <= text.length; i++) {
      tester.testTextInput.enterText(text.substring(0, i));
      await frames(3);
    }
    await pause(1);
  }

  /// Mit dem Finger um [dy] logische Pixel nach oben wischen (positiv:
  /// Inhalt wandert nach oben), in [seconds] Sekunden.
  Future<void> scrollBy(
    Finder scrollable,
    double dy, {
    double seconds = 1.2,
  }) async {
    final box = tester.getRect(scrollable.first);
    final start = Offset(
      box.center.dx,
      box.top + box.height * (dy > 0 ? 0.7 : 0.3),
    );
    final gesture = await tester.startGesture(start);
    _touch.value = start;
    await frames(3);
    final steps = (seconds * fps).round();
    var at = start;
    for (var i = 0; i < steps; i++) {
      final move = Offset(0, -dy / steps);
      at += move;
      await gesture.moveBy(move);
      _touch.value = at;
      await frame();
    }
    // Kurz halten, damit kein Schwung entsteht.
    await frames(4);
    await gesture.up();
    _touch.value = null;
    await frames(10);
  }

  /// Zurück über den Pfeil oben links.
  Future<void> back() => tap(
    find.byWidgetPredicate((w) => w is BackButtonIcon || w is CloseButton).last,
  );

  /// Ziel suchen (auch weiter unten in der Liste) und zeigen.
  Future<void> show(Finder target) async {
    await waitFor(target, searchBelow: true);
    await reveal(target);
  }

  // -------------------------------------------------- Simulierte Plattform

  /// Seiten, die der Systemscanner als Nächstes liefert.
  List<String> _scanPaths = const [];

  /// Text je Seite, den die Texterkennung liefert (reihum: erst die
  /// Codes auf dem Original, dann der Text der gespeicherten Seite).
  List<Map<String, Object?>> ocrByPage = const [];
  int _ocrCall = 0;

  void _mockPlatform(TestDefaultBinaryMessenger messenger) {
    messenger.setMockMethodCallHandler(
      const MethodChannel('buchhaltung/document_scanner'),
      (call) async => call.method == 'scan' ? _scanPaths : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('buchhaltung/receipt_text'),
      (call) async => switch (call.method) {
        'isAvailable' => true,
        'recognize' when ocrByPage.isNotEmpty =>
          ocrByPage[_ocrCall++ % ocrByPage.length],
        _ => null,
      },
    );
    // PDF-Seiten wie `printing` auf dem Gerät, gerastert mit pdftoppm.
    const printing = MethodChannel('net.nfet.printing');
    messenger.setMockMethodCallHandler(printing, (call) async {
      if (call.method != 'rasterPdf') return null;
      final args = (call.arguments as Map).cast<String, Object?>();
      final job = args['job'];
      final pages = await _rasterPdf(args['doc']! as Uint8List);
      Future<void> send(String method, Map<String, Object?> arguments) =>
          messenger.handlePlatformMessage(
            printing.name,
            printing.codec.encodeMethodCall(MethodCall(method, arguments)),
            (_) {},
          );
      for (final page in pages) {
        await send('onPageRasterized', {
          'job': job,
          'width': page.width,
          'height': page.height,
          'image': page.getBytes(order: img.ChannelOrder.rgba),
        });
      }
      await send('onPageRasterEnd', {'job': job});
      return null;
    });
  }

  /// Die nächste Aufnahme des Scanners liefert diese Seiten.
  Future<void> prepareScan(List<_Paper> pages) async {
    final paths = (await tester.runAsync(() async {
      final dir = await Directory(
        p.join(docs.path, 'scan'),
      ).create(recursive: true);
      return [
        for (var i = 0; i < pages.length; i++)
          (await File(
            p.join(dir.path, 'seite_${_frame}_$i.png'),
          ).writeAsBytes(await pages[i].png())).path,
      ];
    }))!;
    _scanPaths = paths;
    _ocrCall = 0;
  }

  /// Aufnahmeknopf der Übersicht: Beleg „fotografieren“, Auslesen
  /// abwarten, Felder zeigen.
  Future<void> scanReceipt(_Paper paper, {bool browse = true}) async {
    await prepareScan([paper]);
    ocrByPage = [paper.ocr()];
    await tap(find.byKey(const Key('dashboard-photo')), after: 0);
    await waitFor(
      find.textContaining(RegExp('erkannt|ausgelesen')),
      seconds: 15,
    );
    await pause(3);
    if (browse) {
      // Langsam durch alle Felder: Betrag, Steuersatz, Foto, Händler,
      // Datum, Kategorie.
      for (var i = 0; i < 4; i++) {
        await scrollBy(list, 400, seconds: 1.4);
        await pause(1.6);
      }
    }
  }

  /// Liste nach oben wischen, bis sie am Anfang steht.
  Future<void> scrollToTop() async {
    for (var i = 0; i < 6; i++) {
      final position = tester.state<ScrollableState>(list).position;
      if (position.pixels <= position.minScrollExtent) return;
      await scrollBy(list, -min(position.pixels, 450.0), seconds: 0.9);
    }
  }

  /// Die größte senkrechte Liste der obersten Seite (Formular, Liste);
  /// nicht das Textfeld, das selbst scrollen kann.
  Finder get list {
    final all = find
        .byWidgetPredicate(
          (w) =>
              w is Scrollable &&
              axisDirectionToAxis(w.axisDirection) == Axis.vertical,
        )
        .evaluate()
        // Nur die oberste Seite, nicht die darunterliegende Route.
        .where((e) => ModalRoute.of(e)?.isCurrent ?? true)
        .toList();
    Element? best;
    var area = 0.0;
    for (final e in all) {
      final size = (e.renderObject! as RenderBox).size;
      // Gleich große: die zuletzt gebaute (oberste Seite) gewinnt.
      if (size.width * size.height >= area) {
        area = size.width * size.height;
        best = e;
      }
    }
    return find.byElementPredicate((e) => e == best);
  }

  /// Erfundene EZB-Kurse für den Monat von [date] im lokalen Speicher:
  /// „Kurs abrufen“ findet sie, ohne ins Netz zu gehen.
  Future<void> seedRates(DateTime date) async {
    final rates = [
      for (var d = 1; d <= DateTime(date.year, date.month + 1, 0).day; d++)
        if (DateTime(date.year, date.month, d).weekday <= 5)
          EcbRate(
            DateTime.utc(date.year, date.month, d),
            'USD',
            1085000 + (d % 5) * 1000,
          ),
    ];
    await tester.runAsync(() => ExchangeRateRepository(db).store(rates));
  }

  /// Ziel sichtbar machen, falls es außerhalb der Liste liegt (gewischt,
  /// nicht gesprungen). Unten bleibt Platz für den Aufnahmeknopf.
  Future<void> reveal(Finder target) async {
    for (var i = 0; i < 12; i++) {
      if (!present(target)) return;
      final rect = tester.getRect(target.first);
      final scrollables = find.ancestor(
        of: target.first,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Scrollable &&
              axisDirectionToAxis(w.axisDirection) == Axis.vertical,
        ),
      );
      if (scrollables.evaluate().isEmpty) return;
      final view = tester.getRect(scrollables.first);
      final top = view.top + 24;
      final bottom = view.bottom - 120;
      if (rect.top >= top && rect.bottom <= bottom) return;
      final position = tester
          .state<ScrollableState>(scrollables.first)
          .position;
      final before = position.pixels;
      final delta = rect.bottom > bottom
          ? (rect.center.dy - (top + bottom) / 2).clamp(0, 420).toDouble()
          : -((top + bottom) / 2 - rect.center.dy).clamp(0, 420).toDouble();
      if (delta > 0 && before >= position.maxScrollExtent) return;
      if (delta < 0 && before <= position.minScrollExtent) return;
      await scrollBy(scrollables.first, delta, seconds: 0.8);
      if (position.pixels == before) return;
    }
  }
}

/// Musterfirma (Österreich) in eine beschreibbare Datenbank: Speichern
/// funktioniert, anders als in der schreibgeschützten Demo (FA-13.14).
///
/// [regular]: Regelbesteuerung statt Kleinunternehmerin, damit die
/// UVA-Kennzahlen (A10) nicht leer sind.
Future<void> _seed(Database db, Directory docs, {bool regular = false}) async {
  final images = Directory(p.join(docs.path, 'belege'));
  await images.create(recursive: true);
  await DemoDataset.seed(
    db,
    today: DateTime.now(),
    country: Country.at,
    writeImage: (name, png) async {
      await File(p.join(images.path, name)).writeAsBytes(png);
      return p.join('belege', name);
    },
  );
  final repos = Repositories(db);
  final profile = await repos.company.load();
  await repos.company.save(
    profile!.copyWith(
      companyName: 'Grafikdesign Muster',
      isSmallBusiness: !regular,
    ),
  );
  // Archiv (A11): einige Belege mit Foto auch im Vorjahr.
  final receipts = await repos.receipts.query();
  for (final r in receipts.where((r) => r.hasImage).take(6)) {
    await repos.receipts.save(
      Receipt(
        date: DateTime(r.date.year - 1, r.date.month, r.date.day),
        direction: r.direction,
        description: r.description,
        counterparty: r.counterparty,
        net: r.net,
        vat: r.vat,
        gross: r.gross,
        vatPermille: r.vatPermille,
        categoryId: r.categoryId,
        paymentMethod: r.paymentMethod,
      ),
      pages: [r.imagePath!],
    );
  }
  // Ohne Sicherungshinweis: Sicherung „heute“ erledigt.
  await db.update('company_profile', {
    'last_backup_at': DateTime.now().toIso8601String(),
  });
}

/// Schlichte Statusleiste der Aufnahme: 9:41, Empfang, WLAN, voller Akku.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF1B1B1F);
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            '9:41',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          Spacer(),
          Icon(Icons.signal_cellular_4_bar, size: 16, color: color),
          SizedBox(width: 4),
          Icon(Icons.wifi, size: 16, color: color),
          SizedBox(width: 4),
          Icon(Icons.battery_full, size: 16, color: color),
        ],
      ),
    );
  }
}

/// Touch-Anzeige: halbtransparenter Kreis unter dem Finger.
class _TouchPainter extends CustomPainter {
  const _TouchPainter(this.at);

  final Offset? at;

  @override
  void paint(Canvas canvas, Size size) {
    final at = this.at;
    if (at == null) return;
    canvas.drawCircle(at, 24, Paint()..color = const Color(0x55000000));
    canvas.drawCircle(
      at,
      24,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xCCFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_TouchPainter old) => old.at != at;
}

/// Echte Schriften statt Ahem (wie `store_screenshots_test.dart`).
Future<void> _loadFonts() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      p.dirname(p.dirname(Platform.resolvedExecutable));
  final material = Directory(
    p.join(root, 'bin', 'cache', 'artifacts', 'material_fonts'),
  );
  Future<void> load(String family, Iterable<File> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = await f.readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', [
    for (final name in [
      'Roboto-Regular',
      'Roboto-Medium',
      'Roboto-Bold',
      'Roboto-Light',
      'Roboto-Italic',
    ])
      File(p.join(material.path, '$name.ttf')),
  ]);
  await load('MaterialIcons', [
    File(p.join(material.path, 'MaterialIcons-Regular.otf')),
  ]);
  await load('WorkSans', [
    File('assets/fonts/WorkSans-Regular.ttf'),
    File('assets/fonts/WorkSans-Bold.ttf'),
  ]);
}

/// Ein erfundener Beleg oder eine Vertragsseite: Bild (im Code gezeichnet,
/// P-R56) und derselbe Text als Ergebnis der Texterkennung.
class _Paper {
  const _Paper(this.rows, {this.big = const {0}, this.width = 380});

  /// Zeilen als (Text, Betrag rechtsbündig).
  final List<(String, String)> rows;

  /// Zeilen in großer Schrift.
  final Set<int> big;

  /// Breite in Pixeln; die Höhe ist hochkant wie ein Kassabon bzw. A4.
  final int width;

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  /// A2: Kassabon aus Österreich, 20 %.
  static _Paper papeterie(DateTime date) => _Paper(
    [
      ('Papeterie Sonnenschein', ''),
      ('Musterweg 12, 1070 Wien', ''),
      ('Datum ${_d(date)}  10:42', ''),
      ('Druckerpapier A4 500 Blatt', '12,90'),
      ('Ordner breit 3 Stk', '11,70'),
      ('Kugelschreiber 4 Stk', '6,40'),
      ('SUMME EUR', '31,00'),
      ('MwSt 20%  Netto 25,83', '5,17'),
      ('Bar', '31,00'),
      ('Danke für Ihren Einkauf', ''),
    ],
    big: {0, 6},
  );

  /// A7: zweiter Kassabon, Büromaterial.
  static _Paper office(DateTime date) => _Paper(
    [
      ('Bürowelt Mustermann', ''),
      ('Ringstraße 5, 4020 Linz', ''),
      ('Datum ${_d(date)}  15:08', ''),
      ('Toner schwarz', '64,90'),
      ('Etiketten', '9,80'),
      ('SUMME EUR', '74,70'),
      ('MwSt 20%  Netto 62,25', '12,45'),
      ('Karte', '74,70'),
    ],
    big: {0, 5},
  );

  /// A3: slowenischer Beleg (DDV 22 %).
  static _Paper slovenian(DateTime date) => _Paper(
    [
      ('Papirnica Lipa d.o.o.', ''),
      ('Prešernova 1, 1000 Ljubljana', ''),
      ('ID za DDV: SI00000000', ''),
      ('Datum: ${_d(date)}', ''),
      ('Papir A4', '14,90'),
      ('Mapa', '11,00'),
      ('Skupaj EUR:', '25,90'),
      ('DDV % 22,0  Osnova 21,23  DDV', '4,67'),
    ],
    big: {0, 6},
  );

  /// A4: englische Rechnung in USD (Software-Abo).
  static _Paper usd(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return _Paper([
      ('Cloud Muster Inc.', ''),
      ('INVOICE', ''),
      ('Invoice No: INV-${date.year}-0815', ''),
      ('Date: ${months[date.month - 1]} ${date.day}, ${date.year}', ''),
      ('Design suite (monthly)', r'$29.00'),
      ('Subtotal', r'$29.00'),
      ('Total due', r'$29.00 USD'),
    ]);
  }

  /// A6: Mietvertrag, drei Seiten.
  static List<_Paper> lease(DateTime today) {
    final start = DateTime(today.year, today.month + 1, 1);
    return [
      _Paper([
        ('Mietvertrag', ''),
        ('Vermieter: Hausverwaltung Muster', ''),
        ('Mieterin: Grafikdesign Muster', ''),
        ('Mietgegenstand: Atelier, Musterstraße 1', ''),
        ('Das Mietverhältnis beginnt am ${_d(start)}.', ''),
      ], width: 600),
      const _Paper([
        ('Seite 2', ''),
        ('Die Miete beträgt monatlich EUR 650,00 inkl. USt.', ''),
        ('Fällig jeweils am Ersten des Monats.', ''),
        ('Wertsicherung nach dem Verbraucherpreisindex 2020.', ''),
      ], width: 600),
      _Paper([
        ('Seite 3', ''),
        ('Die Kündigungsfrist beträgt 3 Monate zum Quartalsende.', ''),
        ('Wien, am ${_d(today)}', ''),
      ], width: 600),
    ];
  }

  static const _line = 36;

  /// Bild mit echter Schrift (Umlaute wie auf einem echten Beleg).
  Future<Uint8List> png() async {
    const ink = Color(0xFF1E1E1E);
    TextPainter painter(String text, bool large) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: large ? 26 : 17,
          fontWeight: large ? FontWeight.bold : FontWeight.normal,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    final height = max(40 + rows.length * _line + 60, (width * 1.45).round());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = const Color(0xFFFAFAF6),
      );
    for (var i = 0; i < rows.length; i++) {
      final (text, amount) = rows[i];
      final y = 24.0 + i * _line;
      final right = painter(amount, big.contains(i))..layout();
      right.paint(canvas, Offset(width - 18 - right.width, y));
      final left = painter(text, big.contains(i))
        ..layout(maxWidth: width - 46 - right.width);
      left.paint(canvas, Offset(18, y));
      left.dispose();
      right.dispose();
    }
    final footer = TextPainter(
      text: const TextSpan(
        text: 'MUSTER – DEMO',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          color: Color(0xFF962828),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    footer.paint(canvas, Offset(18, height - 36));
    footer.dispose();
    final image = await recorder.endRecording().toImage(width, height);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return png!.buffer.asUint8List();
  }

  /// Antwort des Texterkennungs-Kanals mit Lage je Zeile.
  Map<String, Object?> ocr() => {
    'engine': 'erklaervideo',
    'engineVersion': '1',
    'codes': <String>[],
    'lines': [
      for (var i = 0; i < rows.length; i++)
        {
          'text': rows[i].$2.isEmpty
              ? rows[i].$1
              : '${rows[i].$1}  ${rows[i].$2}',
          'left': 18,
          'top': 20 + i * _line,
          'height': big.contains(i) ? 24 : 14,
        },
    ],
  };
}

/// PDF-Seiten als Bilder über `pdftoppm` (poppler-utils).
Future<List<img.Image>> _rasterPdf(Uint8List pdf) async {
  final dir = await Directory.systemTemp.createTemp('pdf_raster');
  try {
    final input = File(p.join(dir.path, 'in.pdf'));
    await input.writeAsBytes(pdf);
    final result = await Process.run('pdftoppm', [
      '-png',
      '-r',
      '144',
      input.path,
      p.join(dir.path, 'page'),
    ]);
    if (result.exitCode != 0) {
      throw StateError('pdftoppm: ${result.stderr}');
    }
    final files =
        (await dir.list().toList())
            .whereType<File>()
            .where((f) => f.path.endsWith('.png'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return [for (final f in files) img.decodePng(await f.readAsBytes())!];
  } finally {
    await dir.delete(recursive: true);
  }
}
