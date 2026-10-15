import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/haptics.dart';
import 'floating_nav_bar.dart';

/// Hosts the four tab branches (state of each tab is preserved) and the floating navigation bar.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // content scrolls behind the floating bar
      body: shell,
      bottomNavigationBar: FloatingNavBar(
        currentIndex: shell.currentIndex,
        onSelected: (index) {
          Haptics.tap();
          // Tapping the active tab returns to its root.
          shell.goBranch(index, initialLocation: index == shell.currentIndex);
        },
      ),
    );
  }
}
