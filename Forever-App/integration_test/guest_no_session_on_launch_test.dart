// Launching the app, browsing, and opening the Cart / Profile tabs must NOT
// create a guest cart session (one is started only by add-to-cart).
//   flutter test integration_test/guest_no_session_on_launch_test.dart -d <sim>
// Checked on the device (nothing stored, no provider state) and, around the
// run, server-side by counting `guest_sessions` rows (see the report).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:forever_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:forever_app/features/cart/presentation/providers/guest_session_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launch + Cart tab + Profile: no guest session', (tester) async {
    await launchApp(tester, fresh: true);
    await pumpFor(tester, const Duration(seconds: 3));
    final container = appContainer(tester);
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    router.go('/cart');
    await pumpUntil(tester, find.text('Your cart is empty'));
    await pumpFor(tester, const Duration(seconds: 2));
    router.go('/collection');
    await pumpFor(tester, const Duration(seconds: 2));
    router.go('/profile');
    await pumpUntil(tester, find.byKey(const Key('profile-logged-out')));
    router.go('/cart');
    await pumpFor(tester, const Duration(seconds: 2));

    expect(container.read(guestSessionProvider), isNull);
    expect(await storedGuestToken(), isNull);
    expect(container.read(currentUserProvider), isNull);
    expect(container.read(cartCountProvider), 0);
  });
}
