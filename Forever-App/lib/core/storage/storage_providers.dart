import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'guest_session_storage.dart';
import 'token_storage.dart';

part 'storage_providers.g.dart';

/// Both are created in `main()` (they need async initialisation) and injected with `overrideWithValue`.
@Riverpod(keepAlive: true)
TokenStorage tokenStorage(Ref ref) =>
    throw UnimplementedError('override tokenStorageProvider in main()');

/// The anonymous cart session token (its own secure-storage key; see [GuestSessionStorage]).
///
/// `main()` injects an instance that was `load()`ed from the keychain; the
/// default (nothing loaded) only serves tests that don't involve a guest cart.
@Riverpod(keepAlive: true)
GuestSessionStorage guestSessionStorage(Ref ref) => GuestSessionStorage();

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) =>
    throw UnimplementedError('override sharedPreferencesProvider in main()');
