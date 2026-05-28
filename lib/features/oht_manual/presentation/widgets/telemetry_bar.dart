import 'package:flutter/material.dart';

import '../../../../core/enums/oht_mode.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../controllers/oht_manual_controller.dart';
import 'motor_display_formatters.dart';

/// Compact telemetry bar — Mode, Speed, Position, Battery, Errors (clickable).
class TelemetryBar extends StatelessWidget {
  const TelemetryBar({
    required this.controller,
    this.onSpeedTap,
    this.onErrorTap,
    super.key,
  });

  final OhtManualController controller;
  final VoidCallback? onSpeedTap;
  final VoidCallback? onErrorTap;

  @override
  Widget build(BuildContext context) {
    final t = controller.telemetry;
    final esActive = controller.emergencyStopActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: esActive
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.surfaceBorder,
        ),
      ),
      child: Row(children: _buildTilesWithDividers(t, esActive)),
    );
  }

  List<Widget> _buildTilesWithDividers(dynamic t, bool esActive) {
    final tiles = _buildTiles(t, esActive);
    final result = <Widget>[];
    for (int i = 0; i < tiles.length; i++) {
      result.add(Expanded(child: tiles[i]));
      if (i < tiles.length - 1) {
        result.add(
          Container(
            width: 1,
            height: 36,
            color: AppColors.surfaceBorder,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
        );
      }
    }
    return result;
  }

  List<Widget> _buildTiles(dynamic t, bool esActive) {
    return [
      _TelemetryTile(
        icon: Icons.tune_rounded,
        label: 'Chế độ',
        value: _modeLabel(t.mode),
        valueColor: _modeColor(t.mode),
      ),
      Pressable(
        enabled: onSpeedTap != null,
        onTap: onSpeedTap,
        pressedScale: 0.98,
        pressedOpacity: 0.78,
        child: _TelemetryTile(
          icon: Icons.speed_rounded,
          label: 'Tốc độ di chuyển',
          value: formatTravelVelocityMps(t),
          valueColor: AppColors.primary,
          trailing: Icon(
            Icons.tune_rounded,
            size: 14,
            color: onSpeedTap != null ? AppColors.primary : AppColors.textHint,
          ),
        ),
      ),
      _TelemetryTile(
        icon: Icons.place_rounded,
        label: 'Vị trí',
        value:
            'X: ${t.positionX.toStringAsFixed(1)}  Y: ${t.positionY.toStringAsFixed(1)}',
        valueColor: AppColors.textSecondary,
      ),
      _TelemetryTile(
        icon: t.isCharging
            ? Icons.battery_charging_full_rounded
            : Icons.battery_full_rounded,
        label: 'Pin',
        value: '${t.batteryLevel}%${t.isCharging ? ' (Đang sạc)' : ''}',
        valueColor: t.batteryLevel > 20 ? AppColors.success : AppColors.error,
      ),
      // Errors — clickable
      Pressable(
        enabled: onErrorTap != null,
        onTap: onErrorTap,
        pressedScale: 0.98,
        pressedOpacity: 0.78,
        child: _TelemetryTile(
          icon: Icons.error_outline_rounded,
          label: 'Lỗi',
          value: t.errors.isEmpty ? 'Không có' : '${t.errors.length} lỗi',
          valueColor: t.errors.isEmpty ? AppColors.success : AppColors.error,
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 14,
            color: AppColors.textHint,
          ),
        ),
      ),
    ];
  }

  String _modeLabel(OhtMode mode) => switch (mode) {
    OhtMode.manual => 'Manual',
    OhtMode.auto => 'Auto',
    OhtMode.maintenance => 'Bảo trì',
    OhtMode.error => 'Lỗi',
  };

  Color _modeColor(OhtMode mode) => switch (mode) {
    OhtMode.manual => AppColors.primary,
    OhtMode.auto => AppColors.info,
    OhtMode.maintenance => AppColors.warning,
    OhtMode.error => AppColors.error,
  };
}

class _TelemetryTile extends StatelessWidget {
  const _TelemetryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: valueColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}
