import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/catalog/presentation/screens/collection_screen.dart';
import '../../features/catalog/presentation/screens/product_detail_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/info/presentation/about_screen.dart';
import '../../features/info/presentation/contact_screen.dart';
import '../../features/orders/presentation/screens/checkout_screen.dart';
import '../../features/orders/presentation/screens/orders_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../shell/main_shell.dart';
import 'routes.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // Re-run `redirect` whenever the session changes (login, logout, token expiry).
  final authChanges = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => authChanges.value++);
  ref.onDispose(authChanges.dispose);

  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: authChanges,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final user = auth.value;
      final path = state.uri.path;

      if (user?.isAdmin == true &&
          !path.startsWith(Routes.admin) &&
          !Routes.authFlow.contains(path)) {
        return Routes.admin;
      }
      if (path.startsWith(Routes.admin) &&
          user?.isAdmin != true &&
          !auth.isLoading) {
        return user == null
            ? Routes.loginWithRedirect(Routes.admin)
            : Routes.home;
      }

      if (user == null && !auth.isLoading && Routes.protected.contains(path)) {
        return Routes.loginWithRedirect(state.uri.toString());
      }
      if (user != null && Routes.authFlow.contains(path)) {
        return state.uri.queryParameters['redirect'] ?? Routes.home;
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.collection,
                builder: (_, _) => const CollectionScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.cart, builder: (_, _) => const CartScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.product,
        builder: (_, state) => ProductDetailScreen(
          productId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: Routes.checkout, builder: (_, _) => const CheckoutScreen()),
      GoRoute(path: Routes.orders, builder: (_, _) => const OrdersScreen()),
      GoRoute(
        path: Routes.login,
        builder: (_, state) =>
            LoginScreen(redirect: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        path: Routes.register,
        builder: (_, state) =>
            RegisterScreen(redirect: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (_, state) => VerifyEmailScreen(
          email: state.uri.queryParameters['email'] ?? '',
          redirect: state.uri.queryParameters['redirect'],
        ),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, state) => ResetPasswordScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(path: Routes.about, builder: (_, _) => const AboutScreen()),
      GoRoute(path: Routes.contact, builder: (_, _) => const ContactScreen()),
      GoRoute(path: Routes.admin, builder: (_, _) => const AdminScreen()),
      GoRoute(
        path: Routes.adminSection,
        builder: (_, state) => AdminScreen(
          section: state.pathParameters['section'],
          initialQuery: state.uri.queryParameters['q'],
          initialStatus: state.uri.queryParameters['status'],
          initialActive: switch (state.uri.queryParameters['visibility']) {
            'visible' => true,
            'hidden' => false,
            _ => null,
          },
        ),
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
    debugLogDiagnostics: kDebugMode,
  );
  ref.onDispose(router.dispose);
  return router;
}
