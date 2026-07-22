import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/assets.dart';
import '../../../../features/auth/application/user_role_provider.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_bottom_nav.dart';
import 'personnel_home_screen.dart';
import 'my_submissions_screen.dart';
import 'member_directory_screen.dart';
import '../../../../features/auth/presentation/screens/profile_screen.dart';
import '../../../../shared/widgets/offline_banner.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';

class PersonnelShell extends ConsumerStatefulWidget {
  const PersonnelShell({super.key});

  @override
  ConsumerState<PersonnelShell> createState() => _PersonnelShellState();
}

class _PersonnelShellState extends ConsumerState<PersonnelShell> {
  int _tabIndex = 0;

  static const _tabs = [
    NavItem(icon: PhosphorIconsRegular.house,           activeIcon: PhosphorIconsFill.house,           label: 'Home'),
    NavItem(icon: PhosphorIconsRegular.userPlus,        activeIcon: PhosphorIconsFill.userPlus,        label: 'Register'),
    NavItem(icon: PhosphorIconsRegular.listChecks,      activeIcon: PhosphorIconsFill.listChecks,      label: 'My Members'),
    NavItem(icon: PhosphorIconsRegular.magnifyingGlass, activeIcon: PhosphorIconsFill.magnifyingGlass, label: 'Search'),
    NavItem(icon: PhosphorIconsRegular.userCircle,      activeIcon: PhosphorIconsFill.userCircle,      label: 'Profile'),
  ];

  static final _screens = [
    const PersonnelHomeScreen(),
    const MySubmissionsScreen(showAppBar: false),
    const MemberDirectoryScreen(showAppBar: false),
    const ProfileScreen(),
  ];

  int _stackIndex(int tabIndex) => tabIndex >= 2 ? tabIndex - 1 : tabIndex;

  void _onTap(int i) {
    HapticFeedback.selectionClick();
    if (i == 1) {
      context.push('/register-member');
      return;
    }
    setState(() => _tabIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    final firstName = userAsync.valueOrNull?.fullName.split(' ').first ?? '';

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: _VanguardAppBar(
        firstName: firstName,
        roleLabel: 'Personnel',
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _stackIndex(_tabIndex),
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _tabIndex,
        items: _tabs,
        onTap: _onTap,
      ),
    );
  }
}

// ── Shared premium app bar used by all shells ─────────────────────────────────
class _VanguardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String firstName;
  final String roleLabel;

  const _VanguardAppBar({
    required this.firstName,
    required this.roleLabel,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);

  @override
  Widget build(BuildContext context) {
    const rColor = AppColors.canopyGreen;

    return AppBar(
      backgroundColor: AppColors.deepCanopy,
      elevation: 0,
      titleSpacing: 16,
      // The NDC identity strip — crisp solid segments, main headers only.
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(6),
        child: NdcFlagStripe(height: 6),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(5), // intentional: pixel-perfect icon fit in 32×32 circle
              child: Image.asset(Assets.ndcUmbrella),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('TEMA WEST', style: AppTextStyles.appBarTitle()),
              if (firstName.isNotEmpty)
                Text(
                  'Hello, $firstName',
                  style: AppTextStyles.caption(color: AppColors.surface.withValues(alpha: 0.65)),
                ),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: rColor.withValues(alpha: 0.18),
            borderRadius: AppRadii.borderPill,
            border: Border.all(color: rColor.withValues(alpha: 0.4), width: 1),
          ),
          child: Text(roleLabel.toUpperCase(), style: AppTextStyles.badge(color: AppColors.surface)),
        ),
        const NotificationBell(),
      ],
    );
  }
}

