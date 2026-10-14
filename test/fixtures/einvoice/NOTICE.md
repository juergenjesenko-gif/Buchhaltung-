# Testdaten E-Rechnung

- `01.01a-INVOICE_ubl.xml`, `01.01a-INVOICE_uncefact.xml`: unverändert aus der
  XRechnung-Testsuite der KoSIT (github.com/itplr-kosit/xrechnung-testsuite,
  `src/test/business-cases/standard/`), Apache License 2.0.
- `ebinterface_6p1.xml`: nach Schema ebInterface 6.1 (ebinterface.at) von Hand
  erstellt, synthetische Werte.
- `zugferd_synthetisch.pdf`: minimale PDF mit eingebettetem
  `factur-x.xml` (= `01.01a-INVOICE_uncefact.xml`, FlateDecode), erzeugt mit
  `tool/ci/make_zugferd_fixture.py`; kein PDF/A-3, nur für den Parser.
