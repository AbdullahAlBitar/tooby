import 'package:flutter/material.dart';

/// Key for the app's root navigator, so the player layer (which lives above
/// the navigator) can push pages such as the tag feed.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Tracks whether the root navigator is showing its first page (the one with
/// the bottom navigation bar), so the mini-player can sit above that bar.
class RootRouteObserver extends NavigatorObserver {
  RootRouteObserver._();
  static final RootRouteObserver instance = RootRouteObserver._();

  final ValueNotifier<bool> isAtRoot = ValueNotifier<bool>(true);

  /// True while a dialog / bottom sheet is open on the root navigator; the
  /// mini-player hides so it does not cover it.
  final ValueNotifier<bool> hasPopup = ValueNotifier<bool>(false);

  int _pageDepth = 0;
  int _popupDepth = 0;

  void _change(Route route, int delta) {
    if (route is PageRoute) _pageDepth += delta;
    if (route is PopupRoute) _popupDepth += delta;
    // Notify after the current frame; routes change during builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      isAtRoot.value = _pageDepth <= 1;
      hasPopup.value = _popupDepth > 0;
    });
  }

  @override
  void didPush(Route route, Route? previousRoute) => _change(route, 1);

  @override
  void didPop(Route route, Route? previousRoute) => _change(route, -1);

  @override
  void didRemove(Route route, Route? previousRoute) => _change(route, -1);

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (oldRoute != null) _change(oldRoute, -1);
    if (newRoute != null) _change(newRoute, 1);
  }
}

/// Height of the app's bottom [NavigationBar] (without the system inset).
const double kAppNavBarHeight = 64;

/// Height of the docked mini-player.
const double kMiniPlayerHeight = 64;
