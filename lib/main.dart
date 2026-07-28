import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'presentation/pages/home/home_page.dart';
import 'presentation/pages/library/library_page.dart';
import 'presentation/pages/tags/tag_page.dart';
import 'presentation/pages/settings/settings_page.dart';
import 'presentation/pages/player/video_player_page.dart';
import 'presentation/pages/tags/video_tag_editor_page.dart';
import 'presentation/pages/search/search_page.dart';
import 'presentation/pages/tags/tag_feed_page.dart';
import 'presentation/pages/tags/manage_tag_types_page.dart';
import 'presentation/pages/settings/network_settings_page.dart';

final navigationIndexProvider = StateProvider<int>((ref) => 0);

void main() {
  runApp(
    const ProviderScope(
      child: ToobyApp(),
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
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const MainNavigationScreen());
          case '/player':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(builder: (_) => VideoPlayerPage(videoId: args['videoId']));
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

    final List<Widget> pages = [
      const HomePage(),
      const LibraryPage(),
      const TagPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          ref.read(navigationIndexProvider.notifier).state = index;
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.sell), label: 'Tags'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
