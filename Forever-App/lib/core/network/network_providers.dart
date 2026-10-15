import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_config.dart';
import '../storage/storage_providers.dart';
import 'auth_interceptor.dart';

part 'network_providers.g.dart';

/// Server address; user-changeable at runtime (Profile > Server address) and persisted.
@Riverpod(keepAlive: true)
class BaseUrl extends _$BaseUrl {
  @override
  String build() =>
      ref
          .watch(sharedPreferencesProvider)
          .getString(AppConfig.prefsBaseUrlKey) ??
      AppConfig.defaultBaseUrl;

  /// Pass null/empty to go back to the default address.
  Future<void> change(String? url) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final cleaned = url?.trim().replaceAll(RegExp(r'/+$'), '') ?? '';
    if (cleaned.isEmpty) {
      await prefs.remove(AppConfig.prefsBaseUrlKey);
      state = AppConfig.defaultBaseUrl;
    } else {
      await prefs.setString(AppConfig.prefsBaseUrlKey, cleaned);
      state = cleaned;
    }
  }
}

/// Bumped by [AuthInterceptor] when the refresh token is rejected; the auth controller reacts by logging out.
@Riverpod(keepAlive: true)
class SessionExpired extends _$SessionExpired {
  @override
  int build() => 0;

  void trigger() => state++;
}

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  final options = BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    listFormat: ListFormat.multi,
    headers: {'Accept': 'application/json'},
  );
  final client = Dio(options);
  client.interceptors.add(
    AuthInterceptor(
      client: client,
      tokens: ref.watch(tokenStorageProvider),
      refreshClient: Dio(
        options.copyWith(connectTimeout: const Duration(seconds: 10)),
      ),
      onSessionExpired: () =>
          ref.read(sessionExpiredProvider.notifier).trigger(),
    ),
  );
  if (kDebugMode) {
    client.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        responseHeader: false,
        requestBody: false,
        responseBody: false,
      ),
    );
  }
  ref.onDispose(client.close);
  return client;
}
