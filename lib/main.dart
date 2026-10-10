import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_state.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/company_setup_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ohne die Locale-Daten wirft DateFormat('dd.MM.yyyy', 'de_AT') zur Laufzeit.
  await initializeDateFormatting('de');
  final state = await AppState.open();
  // Wöchentliche UID-Prüfung (Opt-in): beim Start und bei jeder Rückkehr in
  // die App, sobald sie fällig ist.
  // Ebenso die automatische Sicherung (L-7.2), wenn eingeschaltet.
  unawaited(state.runVatChecksIfDue());
  unawaited(state.runAutoBackupIfDue());
  _lifecycle = AppLifecycleListener(
    onResume: () {
      unawaited(state.runVatChecksIfDue());
      unawaited(state.runAutoBackupIfDue());
    },
  );
  runApp(BuchhaltungApp(state: state));
}

// Hält den Listener für die Lebensdauer der App.
// ignore: unused_element
late final AppLifecycleListener _lifecycle;

class BuchhaltungApp extends StatelessWidget {
  const BuchhaltungApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Buchhaltung',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de', 'AT'), Locale('de', 'DE')],
        locale: const Locale('de'),
        home: const _Root(),
      ),
    );
  }
}

/// Entscheidet, ob Onboarding oder Hauptnavigation gezeigt wird.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.needsOnboarding) {
      return const CompanySetupScreen(isOnboarding: true);
    }
    return const HomeShell();
  }
}
