import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/network_providers.dart';
import '../../../../core/storage/storage_providers.dart';
import '../../data/datasources/guest_session_remote_data_source.dart';

part 'guest_session_providers.g.dart';

@Riverpod(keepAlive: true)
GuestSessionRemoteDataSource guestSessionRemoteDataSource(Ref ref) =>
    GuestSessionRemoteDataSource(ref.watch(dioProvider));

/// The anonymous shopper's cart session token, or null when there is none.
///
/// A guest session is NOT a login: `currentUserProvider` stays null. It is
/// created lazily by [ensure] — only when an anonymous shopper adds to cart —
/// and persisted (own secure-storage key) so the cart survives restarts.
@Riverpod(keepAlive: true)
class GuestSession extends _$GuestSession {
  Future<String>? _starting;

  @override
  String? build() {
    // The interceptor already deleted the stored token on GUEST_SESSION_EXPIRED.
    ref.listen(guestSessionExpiredProvider, (_, _) => state = null);
    return ref.read(guestSessionStorageProvider).token;
  }

  /// The current token, starting a session first if there is none (used only
  /// by add-to-cart).
  /// Concurrent callers share one in-flight request (one session, not many).
  Future<String> ensureGuestSession() {
    final current = ref.read(guestSessionStorageProvider).token;
    if (current != null) {
      if (state != current) state = current;
      return Future.value(current);
    }
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<String> _start() async {
    final token = await ref.read(guestSessionRemoteDataSourceProvider).start();
    await ref.read(guestSessionStorageProvider).save(token);
    state = token;
    return token;
  }

  /// Ends the session: revoked server-side (best effort — failures are
  /// ignored, the server expires it anyway) and always deleted locally.
  Future<void> end() async {
    final storage = ref.read(guestSessionStorageProvider);
    final token = storage.token;
    if (token == null) return;
    await storage.clear();
    state = null;
    try {
      await ref
          .read(guestSessionRemoteDataSourceProvider)
          .end(token)
          .timeout(const Duration(seconds: 5));
    } on Object {
      // Best effort.
    }
  }
}
