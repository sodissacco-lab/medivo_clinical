import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recent_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/search_screen.dart';
import 'services/search_service.dart';

/// The five bottom tabs from blueprint §5: Home, Search, Saved, Recent, Me.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _goTo(int index) {
    setState(() => _index = index);
    if (index != 1) SearchService.focusNode.unfocus();
  }

  /// The Home search box takes you to Search with the cursor ready.
  void _openSearch() {
    _goTo(1);
    WidgetsBinding.instance.addPostFrameCallback((_) => SearchService.focusNode.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onOpenSearch: _openSearch, onOpenProfile: () => _goTo(4)),
      const SearchScreen(),
      const SavedScreen(),
      const RecentScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
              icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'Saved'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Recent'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}