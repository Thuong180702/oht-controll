import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/oht_ids.dart';
import '../../../../core/enums/connection_phase.dart';
import '../../../../core/enums/event_severity.dart';
import '../../../../core/enums/lidar_zone.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/auth_storage.dart';
import '../../../../core/widgets/pressable.dart';

import '../../data/services/event_log_excel_exporter.dart';
import '../controllers/oht_manual_controller.dart';
import '../widgets/control_panel_widget.dart';
import '../widgets/motor_display_formatters.dart';
import '../widgets/telemetry_bar.dart';

class OhtManualScreen extends StatefulWidget {
  const OhtManualScreen({
    required this.controller,
    required this.username,
    required this.onDisconnect,
    super.key,
  });
  final OhtManualController controller;
  final String username;
  final Future<void> Function() onDisconnect;
  @override
  State<OhtManualScreen> createState() => _OhtManualScreenState();
}

class _OhtManualScreenState extends State<OhtManualScreen> {
  Timer? _pollTimer;
  int _lastRevision = -1;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final rev = widget.controller.revision;
      if (rev != _lastRevision) {
        _lastRevision = rev;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _showLogDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => _FullLogDialog(controller: widget.controller),
    );
  }

  void _showMotorPanel() {
    showDialog<void>(
      context: context,
      builder: (_) => _TabletPanelDialog(
        controller: widget.controller,
        title: 'Dong co',
        icon: Icons.memory_rounded,
        width: 900,
        contentBuilder: (_) => _MotorStatusBox(
          key: const Key('tablet_motor_panel'),
          controller: widget.controller,
          large: true,
        ),
      ),
    );
  }

  void _showSensorPanel() {
    showDialog<void>(
      context: context,
      builder: (_) => _TabletPanelDialog(
        controller: widget.controller,
        title: 'IO / Cam bien',
        icon: Icons.sensors_rounded,
        width: 1120,
        contentBuilder: (_) => _SensorStatusBox(
          key: const Key('tablet_sensor_panel'),
          controller: widget.controller,
          large: true,
        ),
      ),
    );
  }

  void _showSpeedPanel() {
    showDialog<void>(
      context: context,
      builder: (_) => _TabletPanelDialog(
        controller: widget.controller,
        title: 'Toc do',
        icon: Icons.speed_rounded,
        width: 920,
        contentBuilder: (_) => _TabletSpeedPanel(controller: widget.controller),
      ),
    );
  }

  void _showChangePasswordPanel() {
    showDialog<void>(
      context: context,
      builder: (_) => _ChangePasswordDialog(parentContext: context),
    );
  }

  String _sensorSummary(dynamic sensors) {
    if (sensors.hasLidarDanger) return 'Danger';
    if (sensors.hasLidarWarning) return 'Warning';
    return 'OK';
  }

  String _sensorOnSummary(dynamic sensors) {
    final onCount = SensorIds.boolSensorLabels.keys
        .where((id) => sensors.boolValue(id) == true)
        .length;
    return '$onCount/${SensorIds.boolSensorLabels.length} ON';
  }

  Color _sensorSummaryColor(dynamic sensors) {
    if (sensors.hasLidarDanger) return AppColors.error;
    if (sensors.hasLidarWarning) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final esActive = ctrl.emergencyStopActive;
    final sensorState = _sensorSummary(ctrl.telemetry.sensors);
    final sensorOnState = _sensorOnSummary(ctrl.telemetry.sensors);
    final sensorColor = _sensorSummaryColor(ctrl.telemetry.sensors);
    final isAndroidLandscape =
        defaultTargetPlatform == TargetPlatform.android &&
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Top Bar ───
          _TopBar(
            controller: ctrl,
            username: widget.username,
            esActive: esActive,
            onDisconnect: widget.onDisconnect,
            onUserTap: _showChangePasswordPanel,
          ),
          // ─── Body ───
          Expanded(
            child: isAndroidLandscape
                ? _TabletManualLayout(
                    controller: ctrl,
                    onLogTap: _showLogDialog,
                    onMotorTap: _showMotorPanel,
                    onSensorTap: _showSensorPanel,
                    onSpeedTap: _showSpeedPanel,
                  )
                : Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Telemetry
                        TelemetryBar(
                          controller: ctrl,
                          onSpeedTap: _showSpeedPanel,
                          onErrorTap: _showLogDialog,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final useLargeMotor =
                                  constraints.maxHeight >= 600;
                              final motorHeight = useLargeMotor
                                  ? (constraints.maxHeight * 0.36).clamp(
                                      265.0,
                                      330.0,
                                    )
                                  : (constraints.maxHeight * 0.34).clamp(
                                      145.0,
                                      220.0,
                                    );
                              final controlsHeight =
                                  (constraints.maxHeight - motorHeight - 8)
                                      .clamp(0.0, double.infinity)
                                      .toDouble();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Motor status stays visible; sensors open as a detail panel.
                                  SizedBox(
                                    height: motorHeight,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _MotorStatusBox(
                                            controller: ctrl,
                                            large: useLargeMotor,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: useLargeMotor ? 180 : 170,
                                          child: _TabletSummaryTile(
                                            key: const Key(
                                              'desktop_sensor_summary',
                                            ),
                                            icon: Icons.sensors_rounded,
                                            title: 'Sensors',
                                            value:
                                                '$sensorState  $sensorOnState',
                                            color: sensorColor,
                                            onTap: _showSensorPanel,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // 3 Control panels
                                  SizedBox(
                                    height: controlsHeight,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: TravelControlBox(
                                            controller: ctrl,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: HoistControlBox(
                                            controller: ctrl,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SteerControlBox(
                                            controller: ctrl,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        // System bar
                        SystemControlBar(controller: ctrl),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Motor Status Box ───────────────────────────────────────────────────────
class _TabletManualLayout extends StatelessWidget {
  const _TabletManualLayout({
    required this.controller,
    required this.onLogTap,
    required this.onMotorTap,
    required this.onSensorTap,
    required this.onSpeedTap,
  });

  final OhtManualController controller;
  final VoidCallback onLogTap;
  final VoidCallback onMotorTap;
  final VoidCallback onSensorTap;
  final VoidCallback onSpeedTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('tablet_dashboard'),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 72,
            child: _TabletInfoStrip(
              controller: controller,
              onLogTap: onLogTap,
              onMotorTap: onMotorTap,
              onSensorTap: onSensorTap,
              onSpeedTap: onSpeedTap,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: TravelControlBox(controller: controller)),
                const SizedBox(width: 8),
                Expanded(child: HoistControlBox(controller: controller)),
                const SizedBox(width: 8),
                Expanded(child: SteerControlBox(controller: controller)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SystemControlBar(controller: controller),
        ],
      ),
    );
  }
}

class _TabletInfoStrip extends StatelessWidget {
  const _TabletInfoStrip({
    required this.controller,
    required this.onLogTap,
    required this.onMotorTap,
    required this.onSensorTap,
    required this.onSpeedTap,
  });

  final OhtManualController controller;
  final VoidCallback onLogTap;
  final VoidCallback onMotorTap;
  final VoidCallback onSensorTap;
  final VoidCallback onSpeedTap;

  @override
  Widget build(BuildContext context) {
    final t = controller.telemetry;
    final motors = t.motors.values;
    final runningMotors = motors.where((m) => m.state.name == 'running').length;
    final errorMotors = motors.where((m) => m.state.name == 'error').length;
    final sensorState = _sensorSummary(t.sensors);
    final sensorColor = _sensorSummaryColor(t.sensors);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: controller.emergencyStopActive
                    ? AppColors.error.withValues(alpha: 0.5)
                    : AppColors.surfaceBorder,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabletInfoTile(
                    icon: Icons.tune_rounded,
                    label: 'Mode',
                    value: t.mode.name.toUpperCase(),
                    valueColor: AppColors.primary,
                  ),
                ),
                const _TabletDivider(),
                Expanded(
                  child: Pressable(
                    onTap: onSpeedTap,
                    pressedScale: 0.98,
                    pressedOpacity: 0.78,
                    semanticLabel: 'Speed',
                    child: _TabletInfoTile(
                      icon: Icons.speed_rounded,
                      label: 'Speed',
                      value: formatTravelVelocityMps(t),
                      valueColor: AppColors.primary,
                    ),
                  ),
                ),
                const _TabletDivider(),
                Expanded(
                  child: _TabletInfoTile(
                    icon: Icons.place_rounded,
                    label: 'Position',
                    value:
                        'X:${t.positionX.toStringAsFixed(1)} Y:${t.positionY.toStringAsFixed(1)}',
                    valueColor: AppColors.textSecondary,
                  ),
                ),
                const _TabletDivider(),
                Expanded(
                  child: _TabletInfoTile(
                    icon: t.isCharging
                        ? Icons.battery_charging_full_rounded
                        : Icons.battery_full_rounded,
                    label: 'Battery',
                    value: '${t.batteryLevel}%',
                    valueColor: t.batteryLevel > 20
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
                const _TabletDivider(),
                Expanded(
                  child: Pressable(
                    onTap: onLogTap,
                    pressedScale: 0.98,
                    pressedOpacity: 0.78,
                    semanticLabel: 'Errors',
                    child: _TabletInfoTile(
                      icon: Icons.error_outline_rounded,
                      label: 'Errors',
                      value: t.errors.isEmpty ? 'OK' : '${t.errors.length}',
                      valueColor: t.errors.isEmpty
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 126,
          child: _TabletSummaryTile(
            key: const Key('tablet_motor_summary'),
            icon: Icons.memory_rounded,
            title: 'Motors',
            value: errorMotors > 0
                ? '$errorMotors error'
                : '$runningMotors/${MotorIds.all.length} run',
            color: errorMotors > 0 ? AppColors.error : AppColors.primary,
            onTap: onMotorTap,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 126,
          child: _TabletSummaryTile(
            key: const Key('tablet_sensor_summary'),
            icon: Icons.sensors_rounded,
            title: 'Sensors',
            value: sensorState,
            color: sensorColor,
            onTap: onSensorTap,
          ),
        ),
      ],
    );
  }

  String _sensorSummary(dynamic sensors) {
    if (sensors.hasLidarDanger) return 'Danger';
    if (sensors.hasLidarWarning) return 'Warning';
    return 'OK';
  }

  Color _sensorSummaryColor(dynamic sensors) {
    if (sensors.hasLidarDanger) return AppColors.error;
    if (sensors.hasLidarWarning) return AppColors.warning;
    return AppColors.success;
  }
}

class _TabletInfoTile extends StatelessWidget {
  const _TabletInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textHint),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: valueColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabletDivider extends StatelessWidget {
  const _TabletDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.surfaceBorder,
    );
  }
}

class _TabletSummaryTile extends StatelessWidget {
  const _TabletSummaryTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.97,
        pressedOpacity: 0.78,
        semanticLabel: title,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.open_in_new_rounded,
                    size: 12,
                    color: AppColors.textHint,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabletPanelDialog extends StatefulWidget {
  const _TabletPanelDialog({
    required this.controller,
    required this.title,
    required this.icon,
    required this.width,
    required this.contentBuilder,
  });

  final OhtManualController controller;
  final String title;
  final IconData icon;
  final double width;
  final WidgetBuilder contentBuilder;

  @override
  State<_TabletPanelDialog> createState() => _TabletPanelDialogState();
}

class _TabletPanelDialogState extends State<_TabletPanelDialog> {
  Timer? _pollTimer;
  int _lastRevision = -1;

  @override
  void initState() {
    super.initState();
    _lastRevision = widget.controller.revision;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      final revision = widget.controller.revision;
      if (revision != _lastRevision) {
        _lastRevision = revision;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant _TabletPanelDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _lastRevision = widget.controller.revision;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width - 32,
          maxHeight: size.height - 32,
        ),
        child: SizedBox(
          width: widget.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: widget.contentBuilder(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabletSpeedPanel extends StatelessWidget {
  const _TabletSpeedPanel({required this.controller});

  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TabletSpeedControl(
            label: 'Di chuyen',
            icon: Icons.open_with_rounded,
            value: controller.travelSpeed,
            onStep: (delta) => controller.setTravelSpeed(
              (controller.travelSpeed + delta).toDouble(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabletSpeedControl(
            label: 'Nang ha',
            icon: Icons.open_in_full_rounded,
            value: controller.hoistSpeed,
            onStep: (delta) => controller.setHoistSpeed(
              (controller.hoistSpeed + delta).toDouble(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabletSpeedControl(
            label: 'Re huong',
            icon: Icons.turn_right_rounded,
            value: controller.steerSpeed,
            onStep: (delta) => controller.setSteerSpeed(
              (controller.steerSpeed + delta).toDouble(),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabletSpeedControl extends StatelessWidget {
  const _TabletSpeedControl({
    required this.label,
    required this.icon,
    required this.value,
    required this.onStep,
  });

  final String label;
  final IconData icon;
  final int value;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySurfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _TabletSpeedButton(
                icon: Icons.remove_rounded,
                enabled: value > 0,
                onStep: () => onStep(-1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    formatCommandSpeedMps(value),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              _TabletSpeedButton(
                icon: Icons.add_rounded,
                enabled: value < 100,
                onStep: () => onStep(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabletSpeedButton extends StatefulWidget {
  const _TabletSpeedButton({
    required this.icon,
    required this.enabled,
    required this.onStep,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onStep;

  @override
  State<_TabletSpeedButton> createState() => _TabletSpeedButtonState();
}

class _TabletSpeedButtonState extends State<_TabletSpeedButton> {
  Timer? _timer;

  void _start() {
    if (!widget.enabled) return;
    widget.onStep();
    _timer = Timer(const Duration(milliseconds: 320), () {
      _timer = Timer.periodic(const Duration(milliseconds: 55), (_) {
        if (widget.enabled) widget.onStep();
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didUpdateWidget(covariant _TabletSpeedButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _stop();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      enabled: widget.enabled,
      onPressStart: _start,
      onPressEnd: _stop,
      pressedScale: 0.88,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: widget.enabled
              ? AppColors.primarySurface
              : AppColors.surfaceBorder,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.enabled
                ? AppColors.primary.withValues(alpha: 0.42)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          widget.icon,
          size: 30,
          color: widget.enabled ? AppColors.primary : AppColors.textHint,
        ),
      ),
    );
  }
}

class _MotorStatusBox extends StatelessWidget {
  const _MotorStatusBox({
    required this.controller,
    this.large = false,
    super.key,
  });

  final OhtManualController controller;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final motors = controller.telemetry.motors;
    final sensors = controller.telemetry.sensors;
    final spacing = large ? 10.0 : 5.0;
    return Container(
      padding: EdgeInsets.all(large ? 16 : 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(large ? 12 : 10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.memory_rounded,
                size: large ? 19 : 13,
                color: AppColors.primary,
              ),
              SizedBox(width: large ? 10 : 6),
              Text(
                'ĐỘNG CƠ',
                style: TextStyle(
                  fontSize: large ? 15 : 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: large ? 14 : 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: MotorIds.all.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              mainAxisExtent: large ? 92 : 48,
            ),
            itemBuilder: (_, i) {
              final id = MotorIds.all[i];
              final m = motors[id];
              final label = MotorIds.labels[id] ?? id;
              final running = m?.state.name == 'running';
              final hasError = m?.state.name == 'error';
              final color = hasError
                  ? AppColors.error
                  : running
                  ? AppColors.success
                  : AppColors.textHint;
              return Container(
                padding: large
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                    : const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(large ? 10 : 6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: large ? 10 : 6,
                          height: large ? 10 : 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: large ? 8 : 4),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: large ? 13 : 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: large ? 8 : 2),
                    Text(
                      formatMotorDetails(id, m, sensors),
                      maxLines: large ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: large ? 13 : 9,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Sensor Status Box ──────────────────────────────────────────────────────
class _SensorStatusBox extends StatelessWidget {
  const _SensorStatusBox({
    required this.controller,
    this.large = false,
    super.key,
  });

  final OhtManualController controller;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final sensors = controller.telemetry.sensors;
    final spacing = large ? 10.0 : 5.0;
    // 8 bool sensors + 2 lidar = 10 items in 5×2 grid
    final items = <_SensorItem>[
      for (final e in SensorIds.boolSensorLabels.entries)
        _SensorItem(
          label: e.value,
          boolVal: sensors.boolValue(e.key),
          isLimit: _isLimit(e.key),
        ),
      _SensorItem(
        label: 'Lidar Upper',
        lidarZone: sensors.lidarValue(SensorIds.lidarUpper),
      ),
      _SensorItem(
        label: 'Lidar Lower',
        lidarZone: sensors.lidarValue(SensorIds.lidarLower),
      ),
    ];
    return Container(
      padding: EdgeInsets.all(large ? 16 : 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(large ? 12 : 10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.sensors_rounded,
                size: large ? 19 : 13,
                color: AppColors.primary,
              ),
              SizedBox(width: large ? 10 : 6),
              Text(
                'IO / CẢM BIẾN',
                style: TextStyle(
                  fontSize: large ? 15 : 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: large ? 14 : 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              mainAxisExtent: large ? 84 : 48,
            ),
            itemBuilder: (_, i) => items[i].build(large: large),
          ),
        ],
      ),
    );
  }

  bool _isLimit(String key) =>
      key == SensorIds.hoistFrontUpperLimit ||
      key == SensorIds.hoistRearUpperLimit ||
      key == SensorIds.steerFrontLeft ||
      key == SensorIds.steerFrontRight ||
      key == SensorIds.steerRearLeft ||
      key == SensorIds.steerRearRight;
}

class _SensorItem {
  const _SensorItem({
    required this.label,
    this.boolVal,
    this.lidarZone,
    this.isLimit = false,
  });
  final String label;
  final bool? boolVal;
  final LidarZone? lidarZone;
  final bool isLimit;

  Widget build({bool large = false}) {
    final Color color;
    final String txt;
    if (lidarZone != null) {
      color = switch (lidarZone!) {
        LidarZone.clear => AppColors.success,
        LidarZone.warning => AppColors.warning,
        LidarZone.danger => AppColors.error,
        LidarZone.noData => AppColors.textHint,
      };
      txt = switch (lidarZone!) {
        LidarZone.clear => 'OK',
        LidarZone.warning => '⚠',
        LidarZone.danger => '!!',
        LidarZone.noData => '—',
      };
    } else if (boolVal == null) {
      color = AppColors.textHint;
      txt = '—';
    } else if (boolVal! && isLimit) {
      color = AppColors.warning;
      txt = 'ON';
    } else if (boolVal!) {
      color = AppColors.success;
      txt = 'ON';
    } else {
      color = AppColors.textHint;
      txt = 'OFF';
    }
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(large ? 10 : 6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: large ? 10 : 6,
                height: large ? 10 : 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: large ? 8 : 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: large ? 12 : 8,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: large ? 8 : 2),
          Text(
            txt,
            style: TextStyle(
              fontSize: large ? 13 : 9,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top Bar ────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.username,
    required this.esActive,
    required this.onDisconnect,
    required this.onUserTap,
  });
  final OhtManualController controller;
  final String username;
  final bool esActive;
  final Future<void> Function() onDisconnect;
  final VoidCallback onUserTap;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: esActive ? AppColors.emergency : AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.precision_manufacturing_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          const Text(
            'OHT Control System',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 12),
          _ConnBadge(controller: controller),
          const Spacer(),
          if (esActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_rounded, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text(
                    'EMERGENCY STOP',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
          Pressable(
            onTap: onUserTap,
            pressedOpacity: 0.8,
            pressedScale: 0.98,
            semanticLabel: 'User profile',
            child: Row(
              children: [
                const Icon(
                  Icons.account_circle_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  username,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: onDisconnect,
            icon: const Icon(
              Icons.link_off_rounded,
              color: Colors.white70,
              size: 14,
            ),
            label: const Text(
              'Ngắt kết nối',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.parentContext});
  final BuildContext parentContext;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _ready = false;
  String? _errorText;
  String _currentPassword = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentPassword();
  }

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPassword() async {
    final pwd = await AuthStorage.getPassword();
    if (!mounted) return;
    setState(() {
      _currentPassword = pwd;
      _ready = true;
    });
  }

  void _setError(String message) {
    setState(() => _errorText = message);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_ready) {
      _setError('Đang tải dữ liệu, vui lòng thử lại.');
      return;
    }
    final oldPwd = _oldCtrl.text;
    final newPwd = _newCtrl.text;
    final confirmPwd = _confirmCtrl.text;

    if (oldPwd.isEmpty || newPwd.isEmpty || confirmPwd.isEmpty) {
      _setError('Vui lòng nhập đầy đủ các trường.');
      return;
    }
    if (oldPwd != _currentPassword) {
      _setError('Mật khẩu cũ không đúng.');
      return;
    }
    if (newPwd != confirmPwd) {
      _setError('Mật khẩu mới không khớp.');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });
    await AuthStorage.setPassword(newPwd);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      const SnackBar(
        content: Text('Đã cập nhật mật khẩu.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _oldCtrl,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Mật khẩu cũ'),
              onChanged: (_) => setState(() => _errorText = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCtrl,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
              onChanged: (_) => setState(() => _errorText = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Nhập lại mật khẩu mới',
              ),
              onChanged: (_) => setState(() => _errorText = null),
              onSubmitted: (_) => _save(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}

class _ConnBadge extends StatelessWidget {
  const _ConnBadge({required this.controller});
  final OhtManualController controller;
  @override
  Widget build(BuildContext context) {
    final phase = controller.connectionStatus.phase;
    final (label, color) = switch (phase) {
      ConnectionPhase.connected => ('Đã kết nối', const Color(0xFF4ADE80)),
      ConnectionPhase.connecting => (
        'Đang kết nối...',
        const Color(0xFFFBBF24),
      ),
      ConnectionPhase.timeout => ('Timeout', const Color(0xFFF87171)),
      ConnectionPhase.error => ('Lỗi', const Color(0xFFF87171)),
      ConnectionPhase.disconnected => ('Mất kết nối', const Color(0xFFCBD5E1)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Full Log Dialog ────────────────────────────────────────────────────────
class _FullLogDialog extends StatefulWidget {
  const _FullLogDialog({required this.controller});
  final OhtManualController controller;
  @override
  State<_FullLogDialog> createState() => _FullLogDialogState();
}

class _FullLogDialogState extends State<_FullLogDialog> {
  Timer? _pollTimer;
  int _lastRev = -1;
  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final r = widget.controller.revision;
      if (r != _lastRev) {
        _lastRev = r;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _downloadLog() async {
    try {
      final file = await EventLogExcelExporter.export(widget.controller.events);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã tải log Excel: ${file.path}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải log Excel: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.controller.events;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 660,
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Log lỗi / sự kiện',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${events.length} mục',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: events.isEmpty
                  ? const Center(
                      child: Text(
                        'Không có sự kiện',
                        style: TextStyle(color: AppColors.textHint),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: events.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = events[i];
                        final c = _sevColor(e.severity);
                        final t = e.timestamp;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textHint,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: c.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  e.severity.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w800,
                                    color: c,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  e.message,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _downloadLog,
                    icon: const Icon(Icons.download_rounded, size: 13),
                    label: const Text('Tải xuống Excel'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.controller.clearEvents();
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 13),
                    label: const Text('Xóa log'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _sevColor(EventSeverity s) => switch (s) {
  EventSeverity.info => AppColors.info,
  EventSeverity.warning => AppColors.warning,
  EventSeverity.critical => AppColors.error,
  EventSeverity.command => AppColors.primary,
  EventSeverity.ack => AppColors.success,
  EventSeverity.nack => AppColors.error,
};
