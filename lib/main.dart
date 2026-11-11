import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/navigation.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'player/player_layer.dart';
import 'player/player_service.dart';
import 'presentation/pages/home/home_page.dart';
import 'presentation/pages/library/library_page.dart';
import 'presentation/pages/search/search_page.dart';
import 'presentation/pages/settings/network_settings_page.dart';
import 'presentation/pages/settings/settings_page.dart';
import 'presentation/pages/tags/manage_tag_types_page.dart';
import 'presentation/pages/tags/tag_feed_page.dart';
import 'presentation/pages/tags/tag_page.dart';
import 'presentation/pages/tags/video_tag_editor_page.dart';

final navigationIndexProvider = StateProvider<int>((ref) => 0);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Phone UI is portrait; the player switches to landscape for fullscreen.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final container = ProviderContainer();
  // Create the player now so its back-button handler is registered before
  // the app's navigator (it gets the first chance to handle "back").
  container.read(playerServiceProvider);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ToobyApp(),
    ),
  );
}

class ToobyApp extends StatelessWidget {
  const ToobyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tooby',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [RootRouteObserver.instance],
      initialRoute: '/',
      // The player lives above the navigator so it survives page changes.
      builder: (context, child) => Stack(
        children: [
          child!,
          const Positioned.fill(child: PlayerLayer()),
        ],
      ),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const MainNavigationScreen());
          case '/library':
            return MaterialPageRoute(builder: (_) => const LibraryPage());
          case '/tags':
            return MaterialPageRoute(builder: (_) => const TagPage());
          case '/video-tags':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => VideoTagEditorPage(
                videoId: args['videoId'],
                videoTitle: args['videoTitle'],
              ),
            );
          case '/search':
            return MaterialPageRoute(builder: (_) => const SearchPage());
          case '/settings':
            return MaterialPageRoute(builder: (_) => const SettingsPage());
          case '/network-settings':
            return MaterialPageRoute(builder: (_) => const NetworkSettingsPage());
          case '/tag-feed':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => TagFeedPage(
                tagId: args['tagId'],
                tagName: args['tagName'],
              ),
            );
          case '/manage-tag-types':
            return MaterialPageRoute(builder: (_) => const ManageTagTypesPage());
          default:
            return MaterialPageRoute(builder: (_) => const MainNavigationScreen());
        }
      },
    );
  }
}

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationIndexProvider);

    const pages = [
      HomePage(),
      LibraryPage(),
      TagPage(),
      SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        height: kAppNavBarHeight,
        selectedIndex: selectedIndex,
        backgroundColor: AppColors.surfaceContainerLow,
        indicatorColor: AppColors.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          ref.read(navigationIndexProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.onPrimaryContainer),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library_rounded, color: AppColors.onPrimaryContainer),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.sell_outlined),
            selectedIcon: Icon(Icons.sell_rounded, color: AppColors.onPrimaryContainer),
            label: 'Tags',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: AppColors.onPrimaryContainer),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
