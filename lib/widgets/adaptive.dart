import 'package:flutter/material.dart';

import '../core/window_size.dart';

/// Begrenzt Formulare und Lesetext auf [WindowSizeClass.maxContentWidth] und
/// zentriert sie. Auf dem Telefon wirkungslos.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: WindowSizeClass.maxContentWidth,
      ),
      child: child,
    ),
  );
}

/// Liste-Detail-Muster (DESIGN_SPEC D-5, Spezifikation FA-9.3).
///
/// Ab expanded steht rechts neben der Liste ein eigener Navigator für die
/// Detailseite. [ListDetail.open] schiebt dort hinein; auf schmalen Fenstern
/// wird wie bisher bildschirmfüllend geschoben. Die Detailseiten selbst bleiben
/// unverändert: ihr `Navigator.pop(true)` schließt den Detailbereich, und das
/// Ergebnis kommt bei der Liste an wie beim Vollbild.
class ListDetail extends StatefulWidget {
  const ListDetail({super.key, required this.list, required this.placeholder});

  final Widget list;

  /// Hinweis im leeren Detailbereich.
  final String placeholder;

  /// Öffnet [builder] im Detailbereich, falls einer sichtbar ist, sonst als
  /// neue Seite. Eine bereits offene Detailseite wird ersetzt.
  static Future<T?> open<T>(BuildContext context, WidgetBuilder builder) {
    final scope = context.getInheritedWidgetOfExactType<_ListDetailScope>();
    final detail = scope?.detailNavigator.currentState;
    if (scope != null && scope.showsDetail && detail != null) {
      detail.popUntil((route) => route.isFirst);
      return detail.push<T>(MaterialPageRoute<T>(builder: builder));
    }
    return Navigator.of(
      context,
    ).push<T>(MaterialPageRoute<T>(builder: builder));
  }

  @override
  State<ListDetail> createState() => _ListDetailState();
}

class _ListDetailState extends State<ListDetail> {
  final _detailNavigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final showsDetail = WindowSizeClass.of(context).isExpanded;
    return _ListDetailScope(
      detailNavigator: _detailNavigator,
      showsDetail: showsDetail,
      child: showsDetail
          ? Row(
              children: [
                Expanded(flex: 2, child: widget.list),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 3,
                  child: NavigatorPopHandler(
                    onPopWithResult: (_) =>
                        _detailNavigator.currentState?.maybePop(),
                    child: Navigator(
                      key: _detailNavigator,
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (context) =>
                            _DetailPlaceholder(text: widget.placeholder),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : widget.list,
    );
  }
}

class _ListDetailScope extends InheritedWidget {
  const _ListDetailScope({
    required this.detailNavigator,
    required this.showsDetail,
    required super.child,
  });

  final GlobalKey<NavigatorState> detailNavigator;
  final bool showsDetail;

  @override
  bool updateShouldNotify(_ListDetailScope oldWidget) =>
      showsDetail != oldWidget.showsDetail;
}

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    ),
  );
}

/// Ein Navigationsziel der Hauptnavigation.
class AdaptiveDestination {
  const AdaptiveDestination(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Hauptnavigation je Breitenklasse (Spezifikation FA-9.2): compact
/// `NavigationBar` unten, medium `NavigationRail` mit Beschriftung unter dem
/// Symbol, expanded ausgeklappte `NavigationRail`.
class AdaptiveNavigationScaffold extends StatelessWidget {
  const AdaptiveNavigationScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final size = WindowSizeClass.of(context);
    if (size.isCompact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }
    final extended = size.isExpanded;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
