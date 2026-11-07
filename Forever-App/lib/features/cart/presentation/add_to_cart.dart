import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../catalog/domain/entities/product.dart';
import '../../catalog/presentation/providers/catalog_providers.dart';
import 'providers/cart_providers.dart';
import 'providers/guest_session_providers.dart';

/// Makes sure an anonymous shopper has a guest cart session (no-op when
/// logged in). Waits for a saved login to finish restoring first, so a
/// returning customer never gets a needless guest session.
Future<void> ensureGuestCartSession(WidgetRef ref) async {
  if (ref.read(authControllerProvider).isLoading) {
    try {
      await ref.read(authControllerProvider.future);
    } on Object {
      // Restore failed (offline): carry on as anonymous.
    }
  }
  if (ref.read(currentUserProvider) != null) return;
  await ref.read(guestSessionProvider.notifier).ensureGuestSession();
}

/// Adds [quantity] of [product] in [size] to the cart with snackbar feedback.
///
/// Anonymous shoppers get an anonymous guest cart session lazily, only now
/// that one is actually needed ([ensureGuestCartSession]). That is never a
/// login: they stay logged out. Server errors are shown verbatim — e.g. 409
/// OUT_OF_STOCK ("Only 3 left of X in size M") or 429
/// TOO_MANY_GUEST_SESSIONS. On OUT_OF_STOCK the product is re-fetched so the
/// size/quantity pickers show the fresh stock.
///
/// Returns whether the item was added. The cart badge updates through
/// [cartControllerProvider], whose state the add replaces.
Future<bool> addToCartWithFeedback(
  BuildContext context,
  WidgetRef ref, {
  required Product product,
  required String size,
  required int quantity,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  Future<void> add() async {
    await ensureGuestCartSession(ref);
    await ref
        .read(cartControllerProvider.notifier)
        .add(product.id, size, quantity: quantity);
  }

  try {
    try {
      await add();
    } on AppException catch (e) {
      // The stored guest session had expired server-side (the interceptor
      // already deleted it): this add is the moment to start a new one.
      if (e.code != AuthInterceptor.guestSessionExpiredCode) rethrow;
      await add();
    }
    Haptics.success();
    if (context.mounted) {
      AppSnackbar.info(
        context,
        quantity == 1
            ? 'Added to cart'
            : 'Added $quantity × ${product.name} to cart',
      );
    }
    return true;
  } catch (e) {
    Haptics.error();
    if (e is AppException && e.code == 'OUT_OF_STOCK') {
      ref.invalidate(productDetailProvider(product.id));
    }
    if (context.mounted) {
      AppSnackbar.error(context, e);
    } else if (messenger != null) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    }
    return false;
  }
}
