import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../shared/theme/app_colors.dart';
import 'update_service.dart';

/// Wraps the whole app (via MaterialApp.router `builder`). Once per app launch
/// it checks for a newer APK; if one exists it slides up an on-brand update
/// card over the current screen. Self-rendered overlay (no Navigator needed),
/// so it works regardless of the active route.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

// Guards against re-checking on every widget rebuild — one check per launch.
bool _checkedThisSession = false;

enum _Phase { prompt, downloading, installing, error }

class _UpdateGateState extends State<UpdateGate> {
  UpdateInfo? _info;
  bool _visible = false;
  _Phase _phase = _Phase.prompt;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!_checkedThisSession) {
      _checkedThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    final info = await UpdateService.check();
    if (!mounted || info == null) return;
    setState(() {
      _info = info;
      _visible = true;
    });
  }

  void _dismiss() => setState(() => _visible = false);

  Future<void> _update() async {
    final info = _info;
    if (info == null) return;
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
      _error = null;
    });
    try {
      final apk = await UpdateService.download(
        info.downloadUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _phase = _Phase.installing);
      await UpdateService.install(apk);
      // The system installer is now foregrounded; keep the sheet in the
      // "installing" state behind it. If the user backs out, they can retry.
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_info != null)
          _Overlay(
            visible: _visible,
            child: _card(),
          ),
      ],
    );
  }

  Widget _card() {
    final info = _info!;
    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.inkMuted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.greenTint,
                      shape: BoxShape.circle,
                    ),
                    child: const PhosphorIcon(
                      PhosphorIconsRegular.arrowCircleUp,
                      color: AppColors.canopyGreen,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Update available',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Vanguard v${info.version}'
                          '${info.sizeLabel.isNotEmpty ? '  ·  ${info.sizeLabel}' : ''}',
                          style: const TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _body(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.downloading:
        final pct = (_progress * 100).clamp(0, 100).toStringAsFixed(0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 8,
                backgroundColor: AppColors.greenTint,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.canopyGreen),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Downloading update…  $pct%',
              style: const TextStyle(
                  color: AppColors.inkMuted, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        );
      case _Phase.installing:
        return const Text(
          'Opening the installer — tap Install to finish updating.',
          style: TextStyle(color: AppColors.inkMuted, fontSize: 14, height: 1.4),
        );
      case _Phase.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _error ?? 'Update failed. Please try again.',
              style: const TextStyle(
                  color: AppColors.umbrellaRed, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _secondaryButton('Later', _dismiss)),
                const SizedBox(width: 12),
                Expanded(child: _primaryButton('Retry', _update)),
              ],
            ),
          ],
        );
      case _Phase.prompt:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'A newer version of Vanguard is ready with the latest improvements. '
              'Update now to stay current — it only takes a moment.',
              style: TextStyle(color: AppColors.ink, fontSize: 14.5, height: 1.45),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _secondaryButton('Later', _dismiss)),
                const SizedBox(width: 12),
                Expanded(child: _primaryButton('Update now', _update)),
              ],
            ),
          ],
        );
    }
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 50,
      child: Material(
        color: AppColors.canopyGreen,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.surface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 50,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.inkMuted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrim + slide-up animation wrapper. Tapping the scrim dismisses only when
/// the sheet isn't mid-download (handled by the parent via [visible]).
class _Overlay extends StatelessWidget {
  final bool visible;
  final Widget child;
  const _Overlay({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: visible ? 1 : 0,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: Color(0x8A000000)),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: visible ? 0 : -400,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
