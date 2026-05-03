import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Large circular control — primary VPN affordance.
class ConnectPowerButton extends StatelessWidget {
  const ConnectPowerButton({
    super.key,
    required this.onPressed,
    required this.isOn,
    required this.busy,
    required this.enabled,
  });

  final VoidCallback? onPressed;
  final bool isOn;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).shortestSide * 0.42;
    final diameter = size.clamp(168.0, 260.0);

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isOn
          ? const [AppColors.seaBlueLight, AppColors.seaBlue]
          : const [AppColors.surfaceElevated, AppColors.white],
    );

    final ringColor = busy
        ? AppColors.warning.withValues(alpha: 0.45)
        : (isOn
              ? AppColors.seaBlue.withValues(alpha: 0.35)
              : AppColors.outlineMuted);

    return Semantics(
      button: true,
      enabled: enabled && !busy,
      label: isOn ? 'Disconnect VPN' : 'Connect VPN',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: (!enabled || busy) ? null : onPressed,
          child: Ink(
            width: diameter + 28,
            height: diameter + 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: busy ? 3 : 2),
              boxShadow: [
                if (isOn)
                  BoxShadow(
                    color: AppColors.seaBlue.withValues(alpha: 0.28),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gradient,
                ),
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.seaBlue,
                          ),
                        )
                      : Icon(
                          Icons.power_settings_new_rounded,
                          size: diameter * 0.38,
                          color: isOn
                              ? AppColors.white
                              : AppColors.textSecondary,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
