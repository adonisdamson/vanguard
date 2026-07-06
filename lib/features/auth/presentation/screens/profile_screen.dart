import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/auth_provider.dart';
import '../../application/user_role_provider.dart';
import '../../../../core/constants/build_info.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_shadows.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/ndc_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/inline_load_error.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: [
          _ProfileAppBar(userAsync: userAsync),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, AppSpacing.xl,
              AppSpacing.screenH, AppSpacing.h1,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                userAsync.when(
                  data: (user) => _InfoSection(user: user),
                  loading: () => const SkeletonLoader(height: 140, borderRadius: AppRadii.borderMd),
                  error: (_, _) => InlineLoadError(
                    onRetry: () => ref.invalidate(appUserProvider),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _SettingsTile(
                  icon: PhosphorIconsRegular.lock,
                  label: 'Change password',
                  onTap: () => context.push('/forgot-password'),
                ),
                const SizedBox(height: AppSpacing.xl),
                NdcButton(
                  label: 'Sign out',
                  variant: NdcButtonVariant.ghost,
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.signOut,
                    size: 16,
                    color: AppColors.umbrellaRed,
                  ),
                  onPressed: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAppBar extends StatelessWidget {
  final AsyncValue<AppUser?> userAsync;
  const _ProfileAppBar({required this.userAsync});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.brand,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, AppSpacing.xl,
          AppSpacing.screenH, AppSpacing.xxl,
        ),
        child: userAsync.when(
          data: (user) => _AvatarHeader(user: user),
          loading: () => const _AvatarSkeleton(),
          error: (_, _) => const _AvatarSkeleton(),
        ),
      ),
    );
  }
}

class _AvatarHeader extends StatelessWidget {
  final AppUser? user;
  const _AvatarHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user?.fullName ?? 'User';
    final initials = _initials(name);
    final roleLabel = _roleLabel(user?.role);

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.canopyGreen,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface.withValues(alpha: 0.25), width: 2),
          ),
          child: Center(
            child: Text(
              initials,
              style: AppTextStyles.h1(color: AppColors.surface),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: AppTextStyles.h2(color: AppColors.surface),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.12),
            borderRadius: AppRadii.borderPill,
          ),
          child: Text(
            roleLabel,
            style: AppTextStyles.label(color: AppColors.surface.withValues(alpha: 0.9)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tema West Constituency',
          style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.55)),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    if (parts.first.isNotEmpty) return parts.first[0].toUpperCase();
    return 'U';
  }

  static String _roleLabel(AppUserRole? role) {
    return switch (role) {
      AppUserRole.admin => 'System Administrator',
      AppUserRole.higherAuthority => 'Higher Authority',
      _ => 'Personnel',
    };
  }
}

class _AvatarSkeleton extends StatelessWidget {
  const _AvatarSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonLoader(height: 80, width: 80, borderRadius: BorderRadius.all(Radius.circular(40))),
        SizedBox(height: 12),
        SkeletonLoader(height: 24, width: 160),
        SizedBox(height: 8),
        SkeletonLoader(height: 16, width: 100),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  final AppUser? user;
  const _InfoSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.borderMd,
        boxShadow: AppShadows.e1,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          _InfoRow(icon: PhosphorIconsRegular.envelope, label: 'Email', value: user?.email ?? '—'),
          const Divider(color: AppColors.hairline, height: 1),
          _InfoRow(icon: PhosphorIconsRegular.shieldStar, label: 'Role', value: _roleText(user?.role)),
          const Divider(color: AppColors.hairline, height: 1),
          _InfoRow(icon: PhosphorIconsRegular.mapPin, label: 'Constituency', value: 'Tema West'),
          const Divider(color: AppColors.hairline, height: 1),
          _InfoRow(icon: PhosphorIconsRegular.info, label: 'Build', value: BuildInfo.stamp),
        ],
      ),
    );
  }

  static String _roleText(AppUserRole? role) {
    return switch (role) {
      AppUserRole.admin => 'Administrator',
      AppUserRole.higherAuthority => 'Higher Authority',
      _ => 'Personnel',
    };
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          PhosphorIcon(icon, size: 18, color: AppColors.mist),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.label())),
          Text(value, style: AppTextStyles.bodyMedium(), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.borderMd,
          boxShadow: AppShadows.e1,
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            PhosphorIcon(icon, size: 20, color: AppColors.mist),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTextStyles.body())),
            const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.mist),
          ],
        ),
      ),
    );
  }
}
