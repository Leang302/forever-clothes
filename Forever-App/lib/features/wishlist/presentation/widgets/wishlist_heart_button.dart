import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../catalog/domain/entities/product.dart';
import '../providers/wishlist_providers.dart';

/// Round heart toggle used on product cards and the product detail screen.
class WishlistHeartButton extends ConsumerWidget {
  const WishlistHeartButton({super.key, required this.product, this.size = 36});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(
      wishlistControllerProvider.select(
        (s) => s.value?.any((p) => p.id == product.id) ?? false,
      ),
    );

    Future<void> toggle() async {
      if (ref.read(currentUserProvider) == null) {
        AppSnackbar.info(context, 'Log in to save favourites');
        context.push(Routes.loginWithRedirect(Routes.productPath(product.id)));
        return;
      }
      Haptics.tap();
      try {
        await ref.read(wishlistControllerProvider.notifier).toggle(product);
      } catch (e) {
        if (context.mounted) AppSnackbar.error(context, e);
      }
    }

    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: toggle,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: size * 0.52,
            color: saved ? AppColors.danger : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
