import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../application/auth_provider.dart';
import '../../../members/application/member_providers.dart';
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
                  onTap: () => context.push('/change-password'),
                ),
                const SizedBox(height: AppSpacing.xl),
                NdcButton(
                  label: 'Sign out',
                  variant: NdcButtonVariant.ghost,
                  icon: const PhosphorIcon(
                    PhosphorIconsBold.signOut,
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

class _AvatarHeader extends ConsumerWidget {
  final AppUser? user;
  const _AvatarHeader({required this.user});

  Future<void> _changePhoto(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const PhosphorIcon(PhosphorIconsRegular.camera,
                  color: AppColors.canopyGreen),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const PhosphorIcon(PhosphorIconsRegular.image,
                  color: AppColors.canopyGreen),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(
          source: source, maxWidth: 600, maxHeight: 600, imageQuality: 80);
      if (picked == null) return;
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage.from('member-photos').uploadBinary(
            path,
            await File(picked.path).readAsBytes(),
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: false),
          );
      await Supabase.instance.client
          .from('app_users')
          .update({'avatar_path': path}).eq('id', uid);
      ref.invalidate(appUserProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.umbrellaRed,
          content: Text("Couldn't update your photo. Check your connection and try again.",
              style: AppTextStyles.body(color: AppColors.surface)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user?.fullName ?? 'User';
    final initials = _initials(name);
    final roleLabel = _roleLabel(user?.role);

    Widget avatarInner;
    final avatarPath = user?.avatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final urlAsync = ref.watch(photoUrlProvider(avatarPath));
      avatarInner = urlAsync.when(
        data: (url) => url == null
            ? _initialsCircle(initials)
            : ClipOval(
                child: CachedNetworkImage(
                    imageUrl: url, width: 80, height: 80, fit: BoxFit.cover),
              ),
        loading: () => _initialsCircle(initials),
        error: (_, _) => _initialsCircle(initials),
      );
    } else {
      avatarInner = _initialsCircle(initials);
    }

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.surface.withValues(alpha: 0.25), width: 2),
              ),
              child: avatarInner,
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: GestureDetector(
                onTap: () => _changePhoto(context, ref),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const PhosphorIcon(PhosphorIconsRegular.camera,
                      size: 15, color: AppColors.brand),
                ),
              ),
            ),
          ],
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

  Widget _initialsCircle(String initials) => Container(
        decoration: const BoxDecoration(
          color: AppColors.canopyGreen,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(initials, style: AppTextStyles.h1(color: AppColors.surface)),
        ),
      );

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
          _InfoRow(icon: PhosphorIconsRegular.info, label: 'App version', value: BuildInfo.versionLabel),
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
