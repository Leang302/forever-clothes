// Shared helpers for the on-device integration tests. These drive the REAL
// app against the REAL local backend (Forever-API on :8989, dev-only fake
// Bakong on :9099) — nothing in the app is stubbed.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forever_app/app/app.dart';
import 'package:forever_app/core/storage/guest_session_storage.dart';
import 'package:forever_app/core/storage/storage_providers.dart';
import 'package:forever_app/core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apiBase = 'http://localhost:8989';
const fakeBakong = 'http://localhost:9099';

/// Pumps frames until [finder] matches (the app has live timers — KHQR
/// countdown, polling, spinners — so `pumpAndSettle` would never settle).
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 200),
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure(
    'Timed out after $timeout waiting for ${reason ?? finder.describeMatch(Plurality.one)}',
  );
}

/// Pumps real time for [d] (lets HTTP calls and animations progress).
Future<void> pumpFor(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Starts the app exactly like `main.dart` does: brand-new storage objects
/// loaded from the device keychain/prefs and a brand-new ProviderContainer
/// (any previously pumped app is unmounted first) — i.e. an app restart.
/// With [fresh], stored login tokens, the guest cart session and prefs are
/// wiped first (a just-installed app: no session at all; note the iOS
/// keychain survives an uninstall, hence the explicit wipe).
Future<void> launchApp(WidgetTester tester, {bool fresh = false}) async {
  await tester.pumpWidget(const SizedBox.shrink()); // dispose the old app
  await tester.pump();
  final tokens = TokenStorage();
  final guestSession = GuestSessionStorage();
  await tokens.load();
  await guestSession.load();
  final prefs = await SharedPreferences.getInstance();
  if (fresh) {
    await tokens.clear();
    await guestSession.clear();
    await prefs.clear();
  }
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        guestSessionStorageProvider.overrideWithValue(guestSession),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ForeverApp(),
    ),
  );
}

/// The guest cart token as persisted on the device right now (own key).
Future<String?> storedGuestToken() async {
  final s = GuestSessionStorage();
  await s.load();
  return s.token;
}

/// Fills the checkout form, which a guest gets EMPTY (asserted first).
Future<void> fillCheckout(
  WidgetTester tester, {
  required String email,
  String lastName = 'Tester',
  bool expectEmpty = true,
}) async {
  Future<void> field(String label, String value) async {
    final f = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(f);
    if (expectEmpty) {
      expect(
        tester.widget<TextFormField>(f).controller!.text,
        isEmpty,
        reason: 'guest checkout must start empty: $label',
      );
    }
    await tester.enterText(f, value);
    await tester.pump();
  }

  await field('First name', 'Integration');
  await field('Last name', lastName);
  await field('Email', email);
  await field('Street address', '12 Test Street');
  await field('City', 'Phnom Penh');
  await field('State / province', 'Phnom Penh');
  await field('Zip code', '12000');
  await field('Country', 'Cambodia');
  await field('Phone number', '012 345 678');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
}

/// A Dio with no identity (to probe the API like an outside client would).
Dio plainDio() =>
    Dio(BaseOptions(baseUrl: apiBase, validateStatus: (_) => true));

/// The running app's provider container (to read real state / repositories).
ProviderContainer appContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ForeverApp)));

/// A Dio logged in as the seeded admin, used only for test setup/teardown and
/// server-side assertions — never to fake anything inside the app.
Future<Dio> adminDio() async {
  final dio = Dio(BaseOptions(baseUrl: apiBase));
  final res = await dio.post<Map<String, dynamic>>(
    '/api/auth/login',
    data: {'email': 'admin@forever.com', 'password': 'Admin@12345'},
  );
  dio.options.headers['Authorization'] = 'Bearer ${res.data!['accessToken']}';
  return dio;
}

/// Sets one size's stock through the admin API; returns the previous value.
Future<int> setStock(Dio admin, int productId, String size, int stock) async {
  final product = (await admin.get<Map<String, dynamic>>(
    '/api/admin/products/$productId',
  )).data!;
  final previous = ((product['stock'] as Map)[size] as num).toInt();
  await admin.put<void>(
    '/api/admin/inventory/$productId/${Uri.encodeComponent(size)}',
    data: {'stock': stock},
  );
  return previous;
}

/// Simulates the customer paying the shown QR in their banking app.
Future<void> payQr(String qr, double amount) async {
  await Dio(
    BaseOptions(baseUrl: fakeBakong),
  ).post<void>('/__pay_qr', data: {'qr': qr, 'amount': amount});
}

/// Finds widgets whose key is a `ValueKey<String>` starting with [prefix].
Finder byKeyPrefix(String prefix) => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith(prefix),
  description: 'key starting with "$prefix"',
);

/// Waits for any snackbar to go away (they float over bottom buttons).
Future<void> waitForSnackbars(WidgetTester tester) async {
  final end = DateTime.now().add(const Duration(seconds: 8));
  while (find.byType(SnackBar).evaluate().isNotEmpty &&
      DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
