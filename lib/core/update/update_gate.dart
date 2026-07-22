import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../shared/theme/app_colors.dart';
import 'update_service.dart';

// One silent run per app launch.
bool _ranThisSession = false;

/// Wraps the whole app (via MaterialApp.router `builder`). On launch it checks
/// for a newer build and — if found — downloads it **silently in the
/// background**: no modal, no scrim, no progress popup, and update errors are
/// never surfaced to the user (they just retry next launch).
///
/// When the APK is downloaded and ready, a slim, dismissible banner appears at
/// the bottom offering to install. Android requires the user to confirm a
/// sideloaded install, so that final tap is unavoidable — but nothing pops up
/// until the download is already done.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  String? _readyApkPath;
  String? _readyVersion;
  bool _dismissed = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    if (!_ranThisSession) {
      _ranThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSilently());
    }
  }

  /// Check + download entirely in the background. Any failure is swallowed —
  /// the user never sees an update error, URL, or exception; it simply retries
  /// on the next launch.
  Future<void> _runSilently() async {
    try {
      final info = await UpdateService.check();
      if (info == null || !mounted) return;
      final path = await UpdateService.download(info.downloadUrl);
      if (!mounted || path.isEmpty) return;
      setState(() {
        _readyApkPath = path;
        _readyVersion = info.version;
      });
    } catch (e) {
      // Silent by design. Debug-only log; nothing reaches the UI.
      if (kDebugMode) debugPrint('[update] background update skipped: $e');
    }
  }

  Future<void> _install() async {
    final path = _readyApkPath;
    if (path == null) return;
    setState(() => _installing = true);
    try {
      await UpdateService.install(path); // OS installer takes over from here
    } catch (e) {
      if (kDebugMode) debugPrint('[update] install failed: $e');
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = _readyApkPath != null && !_dismissed;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !show,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              offset: show ? Offset.zero : const Offset(0, 1.6),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: show ? 1 : 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _banner(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _banner() {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.greenTint,
                shape: BoxShape.circle,
              ),
              child: const PhosphorIcon(
                PhosphorIconsRegular.arrowCircleUp,
                color: AppColors.canopyGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update ready',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _readyVersion != null
                        ? 'Version $_readyVersion downloaded'
                        : 'A new version is ready to install',
                    style: const TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Dismiss — 44x44 target.
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: 'Not now',
                onPressed: () => setState(() => _dismissed = true),
                icon: const PhosphorIcon(PhosphorIconsRegular.x,
                    size: 18, color: AppColors.inkMuted),
              ),
            ),
            const SizedBox(width: 2),
            _installButton(),
          ],
        ),
      ),
    );
  }

  Widget _installButton() {
    return SizedBox(
      height: 44,
      child: Material(
        color: AppColors.canopyGreen,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _installing ? null : _install,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              child: _installing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.surface),
                      ),
                    )
                  : const Text(
                      'Install',
                      style: TextStyle(
                        color: AppColors.surface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
