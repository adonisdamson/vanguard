import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Thin bar shown at the top of every shell while the device has no
/// connectivity. Registrations queue offline and sync automatically —
/// this just makes the state visible instead of letting actions
/// mysteriously fail.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snap) {
        final results = snap.data;
        final offline = results != null &&
            (results.isEmpty ||
                results.every((r) => r == ConnectivityResult.none));
        if (!offline) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: AppColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PhosphorIcon(PhosphorIconsRegular.wifiSlash,
                  size: 14, color: AppColors.surface),
              const SizedBox(width: 8),
              Text(
                "You're offline — new registrations will sync when connection returns",
                style: AppTextStyles.caption(color: AppColors.surface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
