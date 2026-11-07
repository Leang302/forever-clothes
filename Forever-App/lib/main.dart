import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/storage/guest_session_storage.dart';
import 'core/storage/storage_providers.dart';
import 'core/storage/token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Async dependencies are created once here and injected, which also keeps providers testable.
  final tokens = TokenStorage();
  final guestSession = GuestSessionStorage();
  final prefs = await SharedPreferences.getInstance();
  await tokens.load();
  await guestSession.load();

  runApp(
    ProviderScope(
      // No automatic background retries: screens show an error with a manual "Try again" instead.
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
