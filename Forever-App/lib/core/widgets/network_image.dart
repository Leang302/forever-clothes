import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Cached remote image with a neutral placeholder and error state.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.radius = 0,
  });

  final String? url;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Widget image = url == null
        ? const _Placeholder(icon: Icons.image_not_supported_outlined)
        : CachedNetworkImage(
            imageUrl: url!,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, _) => const ColoredBox(color: AppColors.fill),
            errorWidget: (_, _, _) =>
                const _Placeholder(icon: Icons.broken_image_outlined),
          );
    return radius == 0
        ? image
        : ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.fill,
    child: Center(child: Icon(icon, color: AppColors.muted)),
  );
}
