import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'profile_sheets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 24),
        children: [
          Text(
            'Profile',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: 30),
          ),
          const SizedBox(height: 20),
          if (user == null) const _GuestCard() else _UserCard(user),
          const SizedBox(height: 22),
          if (user != null)
            _Group(
              children: [
                _Tile(
                  icon: Icons.receipt_long_outlined,
                  title: 'My orders',
                  onTap: () => context.push(Routes.orders),
                ),
                _Tile(
                  icon: Icons.edit_outlined,
                  title: 'Edit profile',
                  onTap: () => _editProfile(context, ref, user),
                ),
                _Tile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Change password',
                  onTap: () => _changePassword(context),
                ),
              ],
            ),
          if (user != null) const SizedBox(height: 16),
          _Group(
            children: [
              _Tile(
                icon: Icons.info_outline_rounded,
                title: 'About Forever',
                onTap: () => context.push(Routes.about),
              ),
              _Tile(
                icon: Icons.support_agent_rounded,
                title: 'Contact us',
                onTap: () => context.push(Routes.contact),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Group(
            children: [
              _Tile(
                icon: Icons.dns_outlined,
                title: 'Server address',
                subtitle: ref.watch(baseUrlProvider),
                onTap: () => _serverAddress(context, ref),
              ),
            ],
          ),
          if (user != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.line),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final saved = await showEditProfileSheet(context, user);
    if (saved == true && context.mounted) {
      AppSnackbar.info(context, 'Profile updated');
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final changed = await showChangePasswordSheet(context);
    if (changed == true && context.mounted) {
      AppSnackbar.info(
        context,
        'Password changed. Other devices were signed out.',
      );
    }
  }

  Future<void> _serverAddress(BuildContext context, WidgetRef ref) async {
    final result = await showServerAddressDialog(
      context,
      ref.read(baseUrlProvider),
    );
    if (result == null) return;
    await applyServerAddress(ref, result);
    if (context.mounted) {
      AppSnackbar.info(context, 'Server set to ${ref.read(baseUrlProvider)}');
    }
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to Forever',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Log in to track your orders and check out faster.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Log in',
                  onPressed: () => context.push(Routes.login),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push(Routes.register),
                  child: const Text('Sign up'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard(this.user);

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.ink, Color(0xFF444444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text(
              user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (user.phone != null)
                  Text(
                    user.phone!,
                    style: const TextStyle(color: AppColors.muted),
                  ),
              ],
            ),
          ),
          if (user.isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Admin',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // A Material (not a coloured DecoratedBox) so the ListTiles' ink splashes stay visible.
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(indent: 68),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.fill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 21, color: AppColors.ink),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
    );
  }
}
