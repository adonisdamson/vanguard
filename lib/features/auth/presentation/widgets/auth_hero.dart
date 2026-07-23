import 'package:flutter/material.dart';
import '../../../../core/constants/assets.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/app_text_styles.dart';

/// Photo hero for the login and request-access screens: the NDC supporters
/// image with a brand gradient scrim so the logo, wordmark, and title read
/// cleanly over it. The scrim deepens into the brand green at the bottom so
/// the form beneath feels connected to the image.
///
/// The height adapts to the viewport — on web/desktop and short windows it
/// shrinks so the sign-in fields stay above the fold instead of being pushed
/// under a tall image. If the photo can't decode (e.g. a cold PWA cache) it
/// degrades to an intentional brand gradient, never a blank block.
class AuthHero extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHero({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = media.padding.top;
    // Compact on wide (web/tablet) or short viewports; full-height on phones.
    final compact = media.size.width > 620 || media.size.height < 720;
    final imageHeight = compact ? 200.0 : 280.0;

    return SizedBox(
      height: imageHeight + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base brand wash — always painted, so even a failed image decode
          // reads as a deliberate green field rather than an empty box.
          const ColoredBox(color: AppColors.deepCanopy),
          Image.asset(
            'assets/images/login_hero.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          // Brand scrim: transparent at top → deep green at the bottom edge.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.deepCanopy.withValues(alpha: 0.55),
                  AppColors.deepCanopy.withValues(alpha: 0.30),
                  AppColors.deepCanopy.withValues(alpha: 0.75),
                  AppColors.deepCanopy,
                ],
                stops: const [0.0, 0.4, 0.8, 1.0],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.screenH, top + 16, AppSpacing.screenH, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                          color: AppColors.surface, shape: BoxShape.circle),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Image.asset(Assets.ndcUmbrella),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('TEMA WEST',
                        style: AppTextStyles.h2(color: AppColors.surface)
                            .copyWith(letterSpacing: 3)),
                  ],
                ),
                const Spacer(),
                Text(title, style: AppTextStyles.display(color: AppColors.surface)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppTextStyles.body(
                        color: AppColors.surface.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
