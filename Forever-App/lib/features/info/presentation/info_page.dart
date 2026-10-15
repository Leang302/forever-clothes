import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/widgets/circle_icon_button.dart';

/// Scrolling page with a back button and large title; used by About and Contact.
class InfoPage extends StatelessWidget {
  const InfoPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                CircleIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.profile),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 26),
                ),
              ],
            ),
            const SizedBox(height: 22),
            ...children,
          ],
        ),
      ),
    );
  }
}
