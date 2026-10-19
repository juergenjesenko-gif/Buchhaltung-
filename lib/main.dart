import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_state.dart';
import 'features/app_lock/lock_screen.dart';
import 'features/demo/demo_screens.dart';
import 'features/demo/demo_sheet.dart';
import 'features/home/home_shell.dart';
import 'features/helper/helper_home_screen.dart';
import 'features/onboarding/company_setup_screen.dart';
import 'features/onboarding/consent_screen.dart';
import 'services/demo/demo_mode.dart';
import 'services/helper/helper_mail_platform.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ohne die Locale-Daten wirft DateFormat('dd.MM.yyyy', 'de_AT') zur Laufzeit.
  await initializeDateFormatting('de');
  registerFontLicense();
  final state = await AppState.open();
  installDemoGuards();
  // Wöchentliche UID-Prüfung (Opt-in): beim Start und bei jeder Rückkehr in
  // die App, sobald sie fällig ist.
  // Ebenso die automatische Sicherung (L-7.2), wenn eingeschaltet.
  unawaited(state.runVatChecksIfDue());
  unawaited(state.runAutoBackupIfDue());
  unawaited(state.syncHelperInbox());
  // Mailweg der Mithelfer (FA-17.9): lesen bzw. senden beim Öffnen, dazu
  // der Hintergrundauftrag passend zur Rolle.
  unawaited(LocalHelperNotifier.instance.init());
  unawaited(state.runMailSync());
  unawaited(state.configureMailBackground());
  // Abo beim Store bestätigen (L-22.5); offline bleibt der gespeicherte Stand.
  unawaited(state.license.refresh());
  _lifecycle = AppLifecycleListener(
    // App-Sperre: Zeitpunkt merken und Inhalt abdecken, sobald die App den
    // Vordergrund verlässt; beim Zurückkehren je nach Sperrzeit sperren.
    onInactive: state.onAppInactive,
    onHide: state.onAppHidden,
    onResume: () {
      state.onAppResumed();
      unawaited(state.runVatChecksIfDue());
      unawaited(state.runAutoBackupIfDue());
      unawaited(state.syncHelperInbox());
      unawaited(state.runMailSync());
    },
  );
  runApp(BuchhaltungApp(state: state));
}

// Hält den Listener für die Lebensdauer der App.
// ignore: unused_element
late final AppLifecycleListener _lifecycle;

/// Navigator der App, damit Demo-Hinweise auch aus Diensten heraus ein
/// Blatt öffnen können (FA-13.14).
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Demo (FA-13.14): blockiertes Teilen/Exportieren und jeder Schreibversuch
/// auf die schreibgeschützte Muster-Datenbank enden beim Hinweisblatt statt
/// bei einer Fehlermeldung.
void installDemoGuards() {
  var showing = false;
  DemoMode.onBlocked = () {
    final context = appNavigatorKey.currentContext;
    if (context == null || showing) return;
    showing = true;
    showDemoSheet(context).whenComplete(() => showing = false);
  };
  final previous = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    if (DemoMode.isWriteBlocked(error)) {
      DemoMode.blocked();
      return true;
    }
    return previous?.call(error, stack) ?? false;
  };
}

class BuchhaltungApp extends StatelessWidget {
  const BuchhaltungApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'JeNi bucht',
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
        navigatorKey: appNavigatorKey,
        home: const _Root(),
        builder: (context, child) => AppLockGate(
          child: DemoFrame(navigator: appNavigatorKey, child: child!),
        ),
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
    if (state.missingConsents.isNotEmpty) {
      return ConsentScreen(texts: state.missingConsents);
    }
    // Mithelfer-Gerät (FA-17.2): nur Erfassung, keine Bücher.
    if (state.isHelperDevice) return const HelperHomeScreen();
    // Store-Build ohne Abo (FA-13.14): Abo wählen oder erst die Demo.
    if (state.showStartChoice) return const StartChoiceScreen();
    if (state.needsOnboarding) {
      return const CompanySetupScreen(isOnboarding: true);
    }
    return const HomeShell();
  }
}

/// Legt in der Demo das Band „DEMO – Abo wählen …“ über alle Seiten
/// (FA-13.14); der Inhalt rückt darunter, die Statusleiste bleibt frei.
class DemoFrame extends StatelessWidget {
  const DemoFrame({super.key, required this.navigator, required this.child});

  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppScope.of(context).isDemo) return child;
    return Column(
      children: [
        DemoBanner(navigator: navigator),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// PDF-Schrift Work Sans (SIL OFL 1.1, P-R18) in „Open-Source-Lizenzen“
/// aufnehmen; Flutter kennt nur die Lizenzen der Pakete.
void registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Work Sans (PDF-Schrift)'], text);
  });
}
