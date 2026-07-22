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
import 'higher_authority_home_screen.dart';
import '../../../../features/members/presentation/screens/member_directory_screen.dart';
import '../../../../features/reports/presentation/screens/reports_screen.dart';
import '../../../../features/auth/presentation/screens/profile_screen.dart';
import '../../../../shared/widgets/offline_banner.dart';
import '../../../../shared/widgets/ndc_flag_stripe.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';

class HigherAuthorityShell extends ConsumerStatefulWidget {
  const HigherAuthorityShell({super.key});

  @override
  ConsumerState<HigherAuthorityShell> createState() => _HigherAuthorityShellState();
}

class _HigherAuthorityShellState extends ConsumerState<HigherAuthorityShell> {
  int _tabIndex = 0;

  static const _tabs = [
    NavItem(icon: PhosphorIconsRegular.house,       activeIcon: PhosphorIconsFill.house,       label: 'Home'),
    NavItem(icon: PhosphorIconsRegular.listChecks,  activeIcon: PhosphorIconsFill.listChecks,  label: 'Review'),
    NavItem(icon: PhosphorIconsRegular.users,       activeIcon: PhosphorIconsFill.users,       label: 'Directory'),
    NavItem(icon: PhosphorIconsRegular.chartBar,    activeIcon: PhosphorIconsFill.chartBar,    label: 'Reports'),
    NavItem(icon: PhosphorIconsRegular.userCircle,  activeIcon: PhosphorIconsFill.userCircle,  label: 'Profile'),
  ];

  static final _screens = [
    const HigherAuthorityHomeScreen(),
    const MemberDirectoryScreen(showAppBar: false),
    const ReportsScreen(),
    const ProfileScreen(),
  ];

  int _stackIndex(int tabIndex) => tabIndex >= 2 ? tabIndex - 1 : tabIndex;

  void _onTap(int i) {
    HapticFeedback.selectionClick();
    if (i == 1) {
      context.push('/review-queue');
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
      appBar: _HaAppBar(firstName: firstName),
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

class _HaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String firstName;
  const _HaAppBar({required this.firstName});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);

  @override
  Widget build(BuildContext context) {
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
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: Padding(
              padding: const EdgeInsets.all(5),
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
            color: AppColors.ink,
            borderRadius: AppRadii.borderPill,
          ),
          child: Text('COORDINATOR', style: AppTextStyles.badge(color: AppColors.surface)),
        ),
        const NotificationBell(),
      ],
    );
  }
}

