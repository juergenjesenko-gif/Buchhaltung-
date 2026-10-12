import 'package:flutter/material.dart';

import '../../widgets/adaptive.dart';
import '../dashboard/dashboard_screen.dart';
import '../export/export_screen.dart';
import '../invoices/invoice_list_screen.dart';
import '../receipts/receipt_list_screen.dart';

/// Hauptnavigation. Vier Bereiche – mehr passt weder auf eine Tab-Leiste noch
/// in den Kopf eines Nutzers, der gerade an der Kassa steht.
///
/// compact: `NavigationBar` unten; medium: `NavigationRail` links;
/// expanded: `NavigationRail` mit Beschriftung (Spezifikation FA-9.2).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    AdaptiveDestination(Icons.dashboard_outlined, Icons.dashboard, 'Übersicht'),
    AdaptiveDestination(
      Icons.receipt_long_outlined,
      Icons.receipt_long,
      'Belege',
    ),
    AdaptiveDestination(
      Icons.description_outlined,
      Icons.description,
      'Rechnungen',
    ),
    AdaptiveDestination(Icons.ios_share_outlined, Icons.ios_share, 'Export'),
  ];

  static const _screens = [
    DashboardScreen(),
    ListDetail(
      list: ReceiptListScreen(),
      placeholder: 'Wähle links einen Beleg aus oder erfasse einen neuen.',
    ),
    ListDetail(
      list: InvoiceListScreen(),
      placeholder: 'Wähle links eine Rechnung aus oder schreibe eine neue.',
    ),
    ExportScreen(),
  ];

  void _select(int value) => setState(() => _index = value);

  @override
  Widget build(BuildContext context) => AdaptiveNavigationScaffold(
    destinations: _destinations,
    selectedIndex: _index,
    onSelected: _select,
    body: IndexedStack(index: _index, children: _screens),
  );
}
