import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/circle_icon_button.dart';

/// Shared frame for the auth screens: back button, brand logo, large title and subtitle.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          tooltip: 'Back',
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go(Routes.home),
                        ),
                        Image.asset('assets/images/logo.png', width: 96),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(fontSize: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ...children,
                    const Spacer(),
                    if (footer != null) ...[
                      const SizedBox(height: 24),
                      Center(child: footer!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Already have an account? Log in" style footer.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 15, color: AppColors.muted),
            children: [
              TextSpan(text: '$prompt '),
              TextSpan(
                text: action,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
