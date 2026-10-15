import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'token_storage.dart';

part 'storage_providers.g.dart';

/// Both are created in `main()` (they need async initialisation) and injected with `overrideWithValue`.
@Riverpod(keepAlive: true)
TokenStorage tokenStorage(Ref ref) =>
    throw UnimplementedError('override tokenStorageProvider in main()');

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) =>
    throw UnimplementedError('override sharedPreferencesProvider in main()');
