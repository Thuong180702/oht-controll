import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/oht_ids.dart';
import '../../../../core/enums/connection_phase.dart';
import '../../../../core/enums/event_severity.dart';
import '../../../../core/enums/lidar_zone.dart';
import '../../../../core/enums/manual_command_type.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_locale.dart';
import '../../../../core/utils/auth_storage.dart';
import '../../../../core/widgets/pressable.dart';

import '../../data/services/event_log_excel_exporter.dart';
import '../../domain/entities/motor_status.dart';
import '../../domain/entities/oht_telemetry.dart';
import '../controllers/oht_manual_controller.dart';
import '../widgets/control_panel_widget.dart';
import '../widgets/emergency_alert_frame.dart';
import '../widgets/industrial_top_bar.dart';
import '../widgets/motor_display_formatters.dart';

class OhtManualScreen extends StatefulWidget {
  const OhtManualScreen({
    required this.controller,
    required this.username,
    required this.activeItem,
    required this.languageCode,
    required this.themeMode,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
    required this.onTopNavSelected,
    required this.onDisconnect,
    super.key,
  });
  final OhtManualController controller;
  final String username;
  final IndustrialTopBarItem activeItem;
  final String languageCode;
  final ThemeMode themeMode;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<IndustrialTopBarItem> onTopNavSelected;
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

  (String, Color) _connectionStatusMeta(ConnectionPhase phase) =>
      switch (phase) {
        ConnectionPhase.connected => ('ONLINE', AppColors.success),
        ConnectionPhase.connecting => ('CONNECTING', AppColors.warning),
        ConnectionPhase.timeout => ('TIMEOUT', AppColors.error),
        ConnectionPhase.error => ('ERROR', AppColors.error),
        ConnectionPhase.disconnected => ('OFFLINE', AppColors.textHint),
      };

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final esActive = ctrl.emergencyStopActive;
    final (connectionLabel, connectionColor) = _connectionStatusMeta(
      ctrl.connectionStatus.phase,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: EmergencyAlertFrame(
        active: esActive || ctrl.hasCriticalError,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Top Bar ───
            IndustrialTopBar(
              activeItem: widget.activeItem,
              username: widget.username,
              languageCode: widget.languageCode,
              statusLabel: connectionLabel,
              statusColor: connectionColor,
              emergencyActive: esActive,
              onItemSelected: widget.onTopNavSelected,
              onEmergencyPressed: () {
                ctrl.sendManualCommand(ManualCommandType.emergencyStop);
                if (mounted) setState(() {});
              },
              onUserTap: _showChangePasswordPanel,
              onExit: () {
                widget.onDisconnect();
              },
              exitLabel: AppLocale.t('Ngắt kết nối'),
              exitIcon: Icons.link_off_rounded,
            ),
            // ─── Body ───
            Expanded(
              child: switch (widget.activeItem) {
                IndustrialTopBarItem.dashboard => _DashboardPanel(
                  controller: ctrl,
                  onSpeedTap: _showSpeedPanel,
                  onLogTap: _showLogDialog,
                ),
                IndustrialTopBarItem.diagnostics => _ResponsiveDiagnosticsPanel(
                  controller: ctrl,
                ),
                IndustrialTopBarItem.logs => _LogsPanel(controller: ctrl),
                IndustrialTopBarItem.settings => _SettingsPanel(
                  controller: ctrl,
                  username: widget.username,
                  languageCode: widget.languageCode,
                  themeMode: widget.themeMode,
                  onLanguageChanged: widget.onLanguageChanged,
                  onThemeModeChanged: widget.onThemeModeChanged,
                  onChangePassword: _showChangePasswordPanel,
                  onDisconnect: widget.onDisconnect,
                ),
                IndustrialTopBarItem.connection => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.controller,
    required this.onSpeedTap,
    required this.onLogTap,
  });

  final OhtManualController controller;
  final VoidCallback onSpeedTap;
  final VoidCallback onLogTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('dashboard_panel'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Utf8DashboardTelemetryStrip(
            controller: controller,
            onSpeedTap: onSpeedTap,
            onLogTap: onLogTap,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 980;
                if (stacked) {
                  return ListView(
                    children: [
                      SizedBox(
                        height: 390,
                        child: _ClassicDashboardManualPanel(
                          controller: controller,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 420,
                        child: _DashboardMapPanel(controller: controller),
                      ),
                    ],
                  );
                }

                final manualWidth = (constraints.maxWidth * 0.24).clamp(
                  430.0,
                  500.0,
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: manualWidth,
                      child: _ClassicDashboardManualPanel(
                        controller: controller,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: _DashboardMapPanel(controller: controller)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Utf8DashboardTelemetryStrip extends StatelessWidget {
  const _Utf8DashboardTelemetryStrip({
    required this.controller,
    required this.onSpeedTap,
    required this.onLogTap,
  });

  final OhtManualController controller;
  final VoidCallback onSpeedTap;
  final VoidCallback onLogTap;

  @override
  Widget build(BuildContext context) {
    final t = controller.telemetry;
    final sensorState = t.sensors.hasLidarDanger
        ? AppLocale.t('NGUY HIỂM')
        : t.sensors.hasLidarWarning
        ? AppLocale.t('CẢNH BÁO')
        : 'OK';
    final zPosition =
        t.motors[MotorIds.hoistFront]?.positionM ??
        t.motors[MotorIds.hoistRear]?.positionM ??
        0.0;
    final steeringState = _dashboardSteeringState(t);

    Widget content() {
      return Row(
        key: const Key('dashboard_telemetry_content'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardTelemetrySlot(
            flex: 21,
            child: _Utf8DashboardStatusMetric(
              connected: t.connected,
              label: t.connected
                  ? AppLocale.t('Trực tuyến')
                  : AppLocale.t('Ngoại tuyến'),
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 11,
            child: _DashboardMetric(
              label: AppLocale.t('CHẾ ĐỘ'),
              value: t.mode.name.toUpperCase(),
              color: AppColors.textPrimary,
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 10,
            child: _DashboardBatteryMetric(
              batteryLevel: t.batteryLevel,
              isCharging: t.isCharging,
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 15,
            child: _DashboardMetric(
              label: AppLocale.t('TỌA ĐỘ'),
              value:
                  '${t.positionX.toStringAsFixed(1)}, ${t.positionY.toStringAsFixed(1)}m',
              color: AppColors.primary,
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 11,
            child: _DashboardMetric(
              key: const Key('dashboard_metric_z'),
              label: AppLocale.t('VỊ TRÍ Z'),
              value: '${(zPosition * 1000).toStringAsFixed(0)} mm',
              color: AppColors.primary,
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 12,
            child: Pressable(
              onTap: onSpeedTap,
              pressedScale: 0.98,
              child: _DashboardMetric(
                label: AppLocale.t('TỐC ĐỘ'),
                value: formatTravelVelocityMps(t),
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 9,
            child: Pressable(
              onTap: onLogTap,
              pressedScale: 0.98,
              child: _DashboardMetric(
                label: AppLocale.t('LỖI'),
                value: t.errors.isEmpty ? '0' : '${t.errors.length}',
                color: t.errors.isEmpty ? AppColors.success : AppColors.error,
              ),
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 12,
            child: _DashboardMetric(
              key: const Key('dashboard_metric_steering'),
              label: AppLocale.t('HƯỚNG LÁI'),
              value: steeringState,
              color: AppColors.textPrimary,
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 13,
            child: _DashboardMetric(
              label: AppLocale.t('TRẠNG THÁI'),
              value: sensorState,
              color: sensorState == 'OK'
                  ? AppColors.success
                  : sensorState == AppLocale.t('CẢNH BÁO')
                  ? AppColors.warning
                  : AppColors.error,
            ),
          ),
        ],
      );
    }

    return Container(
      key: const Key('dashboard_telemetry_strip'),
      height: 82,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1120) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: 1120, child: content()),
            );
          }
          return content();
        },
      ),
    );
  }
}

class _ClassicDashboardManualPanel extends StatelessWidget {
  const _ClassicDashboardManualPanel({required this.controller});

  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dashboard_manual_panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocale.t('Điều Khiển Thủ Công'),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final buttonHeight = ((constraints.maxHeight - 36) / 4)
                    .clamp(52.0, constraints.maxHeight)
                    .toDouble();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: buttonHeight,
                      child: _DashboardControlButton(
                        key: const Key('dashboard_control_forward'),
                        label: AppLocale.t('TIẾN'),
                        icon: Icons.keyboard_arrow_up_rounded,
                        onPressStart: () => controller.sendManualCommand(
                          ManualCommandType.travelForward,
                        ),
                        onPressEnd: () => controller.sendManualCommand(
                          ManualCommandType.travelStop,
                        ),
                        enabled:
                            controller.blockReasonFor(
                              ManualCommandType.travelForward,
                            ) ==
                            null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: buttonHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _DashboardControlButton(
                              key: const Key('dashboard_control_left'),
                              label: AppLocale.t('TRÁI'),
                              icon: Icons.keyboard_arrow_left_rounded,
                              onPressStart: () =>
                                  controller.sendUnifiedSteer(left: true),
                              onPressEnd: () => controller.sendManualCommand(
                                ManualCommandType.steerStop,
                              ),
                              enabled:
                                  controller.blockReasonForUnifiedSteer(
                                    left: true,
                                  ) ==
                                  null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DashboardControlButton(
                              key: const Key('dashboard_control_right'),
                              label: AppLocale.t('PHẢI'),
                              icon: Icons.keyboard_arrow_right_rounded,
                              onPressStart: () =>
                                  controller.sendUnifiedSteer(left: false),
                              onPressEnd: () => controller.sendManualCommand(
                                ManualCommandType.steerStop,
                              ),
                              enabled:
                                  controller.blockReasonForUnifiedSteer(
                                    left: false,
                                  ) ==
                                  null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: buttonHeight,
                      child: _DashboardControlButton(
                        key: const Key('dashboard_control_backward'),
                        label: AppLocale.t('LÙI'),
                        icon: Icons.keyboard_arrow_down_rounded,
                        onPressStart: () => controller.sendManualCommand(
                          ManualCommandType.travelBackward,
                        ),
                        onPressEnd: () => controller.sendManualCommand(
                          ManualCommandType.travelStop,
                        ),
                        enabled:
                            controller.blockReasonFor(
                              ManualCommandType.travelBackward,
                            ) ==
                            null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: buttonHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _DashboardControlButton(
                              key: const Key('dashboard_control_up'),
                              label: AppLocale.t('NÂNG'),
                              icon: Icons.vertical_align_top_rounded,
                              filled: true,
                              onPressStart: () =>
                                  controller.sendUnifiedHoist(up: true),
                              onPressEnd: () => controller.sendManualCommand(
                                ManualCommandType.hoistStop,
                              ),
                              enabled:
                                  controller.blockReasonForUnifiedHoist(
                                    up: true,
                                  ) ==
                                  null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DashboardControlButton(
                              key: const Key('dashboard_control_down'),
                              label: AppLocale.t('HẠ'),
                              icon: Icons.vertical_align_bottom_rounded,
                              onPressStart: () =>
                                  controller.sendUnifiedHoist(up: false),
                              onPressEnd: () => controller.sendManualCommand(
                                ManualCommandType.hoistStop,
                              ),
                              enabled:
                                  controller.blockReasonForUnifiedHoist(
                                    up: false,
                                  ) ==
                                  null,
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
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('dashboard_clear_error_button'),
            onPressed: () =>
                controller.sendManualCommand(ManualCommandType.resetError),
            icon: Icon(Icons.restart_alt_rounded, size: 16),
            label: Text('CLEAR ERROR'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Utf8DashboardStatusMetric extends StatelessWidget {
  const _Utf8DashboardStatusMetric({
    required this.connected,
    required this.label,
  });

  final bool connected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Trạng Thái (Telemetry)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _MiniStatusPill(
            label: label,
            color: connected ? AppColors.success : AppColors.textHint,
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _BalancedDashboardTelemetryStrip extends StatelessWidget {
  const _BalancedDashboardTelemetryStrip({
    required this.controller,
    required this.onSpeedTap,
    required this.onLogTap,
  });

  final OhtManualController controller;
  final VoidCallback onSpeedTap;
  final VoidCallback onLogTap;

  @override
  Widget build(BuildContext context) {
    final t = controller.telemetry;
    final sensorState = t.sensors.hasLidarDanger
        ? 'NGUY HIá»‚M'
        : t.sensors.hasLidarWarning
        ? 'Cáº¢NH BÃO'
        : 'OK';
    final zPosition =
        t.motors[MotorIds.hoistFront]?.positionM ??
        t.motors[MotorIds.hoistRear]?.positionM ??
        0.0;
    final steeringState = _dashboardSteeringState(t);

    Widget content() {
      return Row(
        key: const Key('dashboard_telemetry_content'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardTelemetrySlot(
            flex: 21,
            child: _DashboardStatusMetric(
              connected: t.connected,
              label: t.connected ? 'Trá»±c tuyáº¿n' : 'Ngoáº¡i tuyáº¿n',
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 11,
            child: _DashboardMetric(
              label: 'CHáº¾ Äá»˜',
              value: t.mode.name.toUpperCase(),
              color: AppColors.textPrimary,
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 10,
            child: _DashboardMetric(
              label: 'PIN',
              value: '${t.batteryLevel}%',
              color: t.batteryLevel > 20 ? AppColors.success : AppColors.error,
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 15,
            child: _DashboardMetric(
              label: 'Tá»ŒA Äá»˜',
              value:
                  '${t.positionX.toStringAsFixed(1)}, ${t.positionY.toStringAsFixed(1)}m',
              color: AppColors.primary,
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 11,
            child: _DashboardMetric(
              key: const Key('dashboard_metric_z'),
              label: 'Vá»Š TRÃ Z',
              value: '${(zPosition * 1000).toStringAsFixed(0)} mm',
              color: AppColors.primary,
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 12,
            child: Pressable(
              onTap: onSpeedTap,
              pressedScale: 0.98,
              child: _DashboardMetric(
                label: 'Tá»C Äá»˜',
                value: formatTravelVelocityMps(t),
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 9,
            child: Pressable(
              onTap: onLogTap,
              pressedScale: 0.98,
              child: _DashboardMetric(
                label: 'Lá»–I',
                value: t.errors.isEmpty ? '0' : '${t.errors.length}',
                color: t.errors.isEmpty ? AppColors.success : AppColors.error,
              ),
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 12,
            child: _DashboardMetric(
              key: const Key('dashboard_metric_steering'),
              label: 'HÆ¯á»šNG LÃI',
              value: steeringState,
              color: AppColors.textPrimary,
            ),
          ),
          const _TelemetryDivider(),
          _DashboardTelemetrySlot(
            flex: 13,
            child: _DashboardMetric(
              label: 'TRáº NG THÃI',
              value: sensorState,
              color: sensorState == 'OK'
                  ? AppColors.success
                  : sensorState == 'Cáº¢NH BÃO'
                  ? AppColors.warning
                  : AppColors.error,
            ),
          ),
        ],
      );
    }

    return Container(
      key: const Key('dashboard_telemetry_strip'),
      height: 82,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1120) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: 1120, child: content()),
            );
          }
          return content();
        },
      ),
    );
  }
}

// ignore: unused_element
class _BalancedDashboardManualPanel extends StatelessWidget {
  const _BalancedDashboardManualPanel({required this.controller});

  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dashboard_manual_panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Äiá»u Khiá»ƒn Thá»§ CÃ´ng',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = (constraints.maxWidth - 12) / 2;
                final availableHeight = (constraints.maxHeight - 24)
                    .clamp(1.0, double.infinity)
                    .toDouble();
                final cellHeight = availableHeight / 3;
                return GridView.count(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: cellWidth / cellHeight,
                  children: [
                    _DashboardControlButton(
                      key: const Key('dashboard_control_forward'),
                      label: 'TIáº¾N',
                      icon: Icons.keyboard_arrow_up_rounded,
                      onPressStart: () => controller.sendManualCommand(
                        ManualCommandType.travelForward,
                      ),
                      onPressEnd: () => controller.sendManualCommand(
                        ManualCommandType.travelStop,
                      ),
                      enabled:
                          controller.blockReasonFor(
                            ManualCommandType.travelForward,
                          ) ==
                          null,
                    ),
                    _DashboardControlButton(
                      key: const Key('dashboard_control_backward'),
                      label: 'LÃ™I',
                      icon: Icons.keyboard_arrow_down_rounded,
                      onPressStart: () => controller.sendManualCommand(
                        ManualCommandType.travelBackward,
                      ),
                      onPressEnd: () => controller.sendManualCommand(
                        ManualCommandType.travelStop,
                      ),
                      enabled:
                          controller.blockReasonFor(
                            ManualCommandType.travelBackward,
                          ) ==
                          null,
                    ),
                    _DashboardControlButton(
                      key: const Key('dashboard_control_left'),
                      label: 'TRÃI',
                      icon: Icons.keyboard_arrow_left_rounded,
                      onPressStart: () =>
                          controller.sendUnifiedSteer(left: true),
                      onPressEnd: () => controller.sendManualCommand(
                        ManualCommandType.steerStop,
                      ),
                      enabled:
                          controller.blockReasonForUnifiedSteer(left: true) ==
                          null,
                    ),
                    _DashboardControlButton(
                      key: const Key('dashboard_control_right'),
                      label: 'PHáº¢I',
                      icon: Icons.keyboard_arrow_right_rounded,
                      onPressStart: () =>
                          controller.sendUnifiedSteer(left: false),
                      onPressEnd: () => controller.sendManualCommand(
                        ManualCommandType.steerStop,
                      ),
                      enabled:
                          controller.blockReasonForUnifiedSteer(left: false) ==
                          null,
                    ),
                    _DashboardControlButton(
                      key: const Key('dashboard_control_up'),
                      label: 'NÃ‚NG',
                      icon: Icons.vertical_align_top_rounded,
                      filled: true,
                      onPressStart: () => controller.sendUnifiedHoist(up: true),
                      onPressEnd: () => controller.sendManualCommand(
                        ManualCommandType.hoistStop,
                      ),
                      enabled:
                          controller.blockReasonForUnifiedHoist(up: true) ==
                          null,
                    ),
                    _DashboardControlButton(
                      key: const Key('dashboard_control_down'),
                      label: 'Háº ',
                      icon: Icons.vertical_align_bottom_rounded,
                      onPressStart: () =>
                          controller.sendUnifiedHoist(up: false),
                      onPressEnd: () => controller.sendManualCommand(
                        ManualCommandType.hoistStop,
                      ),
                      enabled:
                          controller.blockReasonForUnifiedHoist(up: false) ==
                          null,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('dashboard_clear_error_button'),
            onPressed: () =>
                controller.sendManualCommand(ManualCommandType.resetError),
            icon: Icon(Icons.restart_alt_rounded, size: 16),
            label: Text('CLEAR ERROR'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTelemetrySlot extends StatelessWidget {
  const _DashboardTelemetrySlot({required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(flex: flex, child: child);
  }
}

class _DashboardStatusMetric extends StatelessWidget {
  const _DashboardStatusMetric({required this.connected, required this.label});

  final bool connected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tráº¡ng ThÃ¡i (Telemetry)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _MiniStatusPill(
            label: label,
            color: connected ? AppColors.success : AppColors.textHint,
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _DashboardTelemetryStrip extends StatelessWidget {
  const _DashboardTelemetryStrip({
    required this.controller,
    required this.onSpeedTap,
    required this.onLogTap,
  });

  final OhtManualController controller;
  final VoidCallback onSpeedTap;
  final VoidCallback onLogTap;

  @override
  Widget build(BuildContext context) {
    final t = controller.telemetry;
    final sensorState = t.sensors.hasLidarDanger
        ? 'NGUY HIỂM'
        : t.sensors.hasLidarWarning
        ? 'CẢNH BÁO'
        : 'OK';
    final zPosition =
        t.motors[MotorIds.hoistFront]?.positionM ??
        t.motors[MotorIds.hoistRear]?.positionM ??
        0.0;
    final steeringState = _dashboardSteeringState(t);

    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 250,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Trạng Thái (Telemetry)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _MiniStatusPill(
                      label: t.connected ? 'Trực tuyến' : 'Ngoại tuyến',
                      color: t.connected
                          ? AppColors.success
                          : AppColors.textHint,
                    ),
                  ],
                ),
              ),
            ),
            const _TelemetryDivider(),
            SizedBox(
              width: 122,
              child: _DashboardMetric(
                label: 'CHẾ ĐỘ',
                value: t.mode.name.toUpperCase(),
                color: AppColors.textPrimary,
              ),
            ),
            const _TelemetryDivider(),
            SizedBox(
              width: 122,
              child: _DashboardMetric(
                label: 'PIN',
                value: '${t.batteryLevel}%',
                color: t.batteryLevel > 20
                    ? AppColors.success
                    : AppColors.error,
              ),
            ),
            const _TelemetryDivider(),
            SizedBox(
              width: 150,
              child: _DashboardMetric(
                label: 'TỌA ĐỘ',
                value:
                    '${t.positionX.toStringAsFixed(1)}, ${t.positionY.toStringAsFixed(1)}m',
                color: AppColors.primary,
              ),
            ),
            const _TelemetryDivider(),
            SizedBox(
              width: 116,
              child: _DashboardMetric(
                key: const Key('dashboard_metric_z'),
                label: 'VỊ TRÍ Z',
                value: '${(zPosition * 1000).toStringAsFixed(0)} mm',
                color: AppColors.primary,
              ),
            ),
            const _TelemetryDivider(),
            SizedBox(
              width: 132,
              child: Pressable(
                onTap: onSpeedTap,
                pressedScale: 0.98,
                child: _DashboardMetric(
                  label: 'TỐC ĐỘ',
                  value: formatTravelVelocityMps(t),
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const _TelemetryDivider(),
            SizedBox(
              width: 112,
              child: Pressable(
                onTap: onLogTap,
                pressedScale: 0.98,
                child: _DashboardMetric(
                  label: 'LỖI',
                  value: t.errors.isEmpty ? '0' : '${t.errors.length}',
                  color: t.errors.isEmpty ? AppColors.success : AppColors.error,
                ),
              ),
            ),
            const _TelemetryDivider(),
            SizedBox(
              width: 126,
              child: _DashboardMetric(
                key: const Key('dashboard_metric_steering'),
                label: 'HƯỚNG LÁI',
                value: steeringState,
                color: AppColors.textPrimary,
              ),
            ),
            const _TelemetryDivider(),
            SizedBox(
              width: 142,
              child: _DashboardMetric(
                label: 'TRẠNG THÁI',
                value: sensorState,
                color: sensorState == 'OK'
                    ? AppColors.success
                    : sensorState == 'CẢNH BÁO'
                    ? AppColors.warning
                    : AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _dashboardSteeringState(OhtTelemetry telemetry) {
  final sensors = telemetry.sensors;
  if (sensors.steerFrontLeft == true || sensors.steerRearLeft == true) {
    return AppLocale.t('TRÁI');
  }
  if (sensors.steerFrontRight == true || sensors.steerRearRight == true) {
    return AppLocale.t('PHẢI');
  }

  final frontDirection = telemetry.motors[MotorIds.steerFront]?.direction;
  final rearDirection = telemetry.motors[MotorIds.steerRear]?.direction;
  final direction = (frontDirection == null || frontDirection == 'none')
      ? rearDirection
      : frontDirection;
  return switch (direction) {
    'left' => AppLocale.t('TRÁI'),
    'right' => AppLocale.t('PHẢI'),
    _ => AppLocale.isEnglish ? 'STRAIGHT' : 'THẲNG',
  };
}

// ignore: unused_element
class _DashboardManualPanel extends StatelessWidget {
  const _DashboardManualPanel({required this.controller});

  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dashboard_manual_panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Điều Khiển Thủ Công',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          if (controller.emergencyStopActive ||
              controller.hasCriticalError) ...[
            Container(
              key: const Key('dashboard_emergency_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.errorBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.error),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.report_problem_outlined,
                    size: 16,
                    color: AppColors.error,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thiết bị đang dừng/lỗi. Nhấn Clear Error để reset.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DashboardControlButton(
                    key: const Key('dashboard_control_forward'),
                    label: 'TIẾN',
                    icon: Icons.keyboard_arrow_up_rounded,
                    onPressStart: () => controller.sendManualCommand(
                      ManualCommandType.travelForward,
                    ),
                    onPressEnd: () => controller.sendManualCommand(
                      ManualCommandType.travelStop,
                    ),
                    enabled:
                        controller.blockReasonFor(
                          ManualCommandType.travelForward,
                        ) ==
                        null,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _DashboardControlButton(
                          key: const Key('dashboard_control_left'),
                          label: 'TRÁI',
                          icon: Icons.keyboard_arrow_left_rounded,
                          onPressStart: () =>
                              controller.sendUnifiedSteer(left: true),
                          onPressEnd: () => controller.sendManualCommand(
                            ManualCommandType.steerStop,
                          ),
                          enabled:
                              controller.blockReasonForUnifiedSteer(
                                left: true,
                              ) ==
                              null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DashboardControlButton(
                          key: const Key('dashboard_control_right'),
                          label: 'PHẢI',
                          icon: Icons.keyboard_arrow_right_rounded,
                          onPressStart: () =>
                              controller.sendUnifiedSteer(left: false),
                          onPressEnd: () => controller.sendManualCommand(
                            ManualCommandType.steerStop,
                          ),
                          enabled:
                              controller.blockReasonForUnifiedSteer(
                                left: false,
                              ) ==
                              null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _DashboardControlButton(
                    key: const Key('dashboard_control_backward'),
                    label: 'LÙI',
                    icon: Icons.keyboard_arrow_down_rounded,
                    onPressStart: () => controller.sendManualCommand(
                      ManualCommandType.travelBackward,
                    ),
                    onPressEnd: () => controller.sendManualCommand(
                      ManualCommandType.travelStop,
                    ),
                    enabled:
                        controller.blockReasonFor(
                          ManualCommandType.travelBackward,
                        ) ==
                        null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DashboardControlButton(
                  key: const Key('dashboard_control_up'),
                  label: 'NÂNG',
                  icon: Icons.vertical_align_top_rounded,
                  filled: true,
                  onPressStart: () => controller.sendUnifiedHoist(up: true),
                  onPressEnd: () =>
                      controller.sendManualCommand(ManualCommandType.hoistStop),
                  enabled:
                      controller.blockReasonForUnifiedHoist(up: true) == null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardControlButton(
                  key: const Key('dashboard_control_down'),
                  label: 'HẠ',
                  icon: Icons.vertical_align_bottom_rounded,
                  onPressStart: () => controller.sendUnifiedHoist(up: false),
                  onPressEnd: () =>
                      controller.sendManualCommand(ManualCommandType.hoistStop),
                  enabled:
                      controller.blockReasonForUnifiedHoist(up: false) == null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('dashboard_clear_error_button'),
            onPressed: () =>
                controller.sendManualCommand(ManualCommandType.resetError),
            icon: Icon(Icons.restart_alt_rounded, size: 16),
            label: Text('CLEAR ERROR'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMapPanel extends StatelessWidget {
  const _DashboardMapPanel({required this.controller});

  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    final t = controller.telemetry;

    return Container(
      key: const Key('dashboard_map_panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocale.t('Bản Đồ Hệ Thống'),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _MapToolIcon(Icons.zoom_in_rounded),
              SizedBox(width: 6),
              _MapToolIcon(Icons.zoom_out_rounded),
              SizedBox(width: 6),
              _MapToolIcon(Icons.center_focus_strong_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: CustomPaint(
                painter: _SystemMapPainter(
                  x: t.positionX,
                  y: t.positionY,
                  warning: t.sensors.hasLidarWarning,
                  danger: t.sensors.hasLidarDanger,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MapLegend(
                color: AppColors.primary,
                label: AppLocale.t('Đường Rail OHT'),
              ),
              SizedBox(width: 14),
              _MapLegend(
                color: AppColors.textHint,
                label: AppLocale.t('Vùng an toàn'),
              ),
              SizedBox(width: 14),
              _MapLegend(
                color: AppColors.error,
                label: AppLocale.t('Lỗi hệ thống'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardControlButton extends StatelessWidget {
  const _DashboardControlButton({
    required super.key,
    required this.label,
    required this.icon,
    required this.onPressStart,
    required this.onPressEnd,
    required this.enabled,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final bool enabled;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background = !enabled
        ? AppColors.surfaceBorder
        : filled
        ? AppColors.primary
        : AppColors.surface;
    final foreground = !enabled
        ? AppColors.textHint
        : filled
        ? Colors.white
        : AppColors.primary;

    return Tooltip(
      message: label,
      child: Pressable(
        enabled: enabled,
        onPressStart: onPressStart,
        onPressEnd: onPressEnd,
        pressedScale: 0.98,
        pressedOpacity: 0.78,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: enabled ? AppColors.surfaceBorder : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
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

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBatteryMetric extends StatelessWidget {
  const _DashboardBatteryMetric({
    required this.batteryLevel,
    required this.isCharging,
  });

  final int batteryLevel;
  final bool isCharging;

  @override
  Widget build(BuildContext context) {
    final color = isCharging
        ? AppColors.info
        : batteryLevel > 20
        ? AppColors.success
        : AppColors.error;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PIN',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                isCharging
                    ? Icons.battery_charging_full_rounded
                    : Icons.battery_full_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '$batteryLevel%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (isCharging) ...[
            const SizedBox(height: 3),
            Container(
              key: const Key('dashboard_battery_charging_indicator'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                AppLocale.t('ĐANG SẠC'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.info,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TelemetryDivider extends StatelessWidget {
  const _TelemetryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: AppColors.surfaceBorder);
  }
}

class _MiniStatusPill extends StatelessWidget {
  const _MiniStatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapToolIcon extends StatelessWidget {
  const _MapToolIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Icon(icon, size: 15, color: AppColors.textSecondary),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
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
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SystemMapPainter extends CustomPainter {
  const _SystemMapPainter({
    required this.x,
    required this.y,
    required this.warning,
    required this.danger,
  });

  final double x;
  final double y;
  final bool warning;
  final bool danger;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF46545E);
    canvas.drawRect(Offset.zero & size, bg);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    for (double dx = 0; dx < size.width; dx += 24) {
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), grid);
    }
    for (double dy = 0; dy < size.height; dy += 24) {
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
    }

    final blueprint = Paint()
      ..color = const Color(0xFFAEC6D2).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final center = Offset(size.width * 0.52, size.height * 0.48);
    final mainRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.42,
      height: size.height * 0.46,
    );
    canvas.drawRect(mainRect, blueprint);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.72,
        30,
        size.width * 0.22,
        size.height * 0.24,
      ),
      blueprint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        24,
        size.height * 0.66,
        size.width * 0.22,
        size.height * 0.26,
      ),
      blueprint,
    );

    final rail = Paint()
      ..color = const Color(0xFFB7E8F8).withValues(alpha: 0.88)
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), rail);
    canvas.drawLine(
      Offset(center.dx, center.dy - 70),
      Offset(center.dx + 90, center.dy - 70),
      rail,
    );

    final pulse = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final robot = Offset(
      (center.dx + x * 0.04).clamp(28.0, size.width - 28),
      (center.dy - y * 0.04).clamp(28.0, size.height - 28),
    );
    canvas.drawCircle(robot, 14, pulse);
    canvas.drawCircle(robot, 5, Paint()..color = AppColors.primary);

    final markerColor = danger
        ? AppColors.error
        : warning
        ? AppColors.warning
        : AppColors.success;
    canvas.drawCircle(
      Offset(size.width * 0.30, center.dy - 75),
      4,
      Paint()..color = markerColor,
    );
  }

  @override
  bool shouldRepaint(covariant _SystemMapPainter oldDelegate) {
    return x != oldDelegate.x ||
        y != oldDelegate.y ||
        warning != oldDelegate.warning ||
        danger != oldDelegate.danger;
  }
}

// ─── Motor Status Box ───────────────────────────────────────────────────────
void _showAdvancedControlDialog(
  BuildContext context,
  OhtManualController controller,
) {
  showDialog<void>(
    context: context,
    builder: (_) => _SizedAdvancedControlDialog(controller: controller),
  );
}

class _ResponsiveDiagnosticsPanel extends StatelessWidget {
  const _ResponsiveDiagnosticsPanel({required this.controller});

  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    final telemetry = controller.telemetry;
    final motors = telemetry.motors;
    final motionMotors = [
      _DiagnosticsMotorSpec(
        id: MotorIds.travelFront,
        title: AppLocale.t('Di chuyển trước'),
        motor: motors[MotorIds.travelFront],
        faultMessage: _motorFaultMessage(
          MotorIds.travelFront,
          telemetry.errors,
        ),
      ),
      _DiagnosticsMotorSpec(
        id: MotorIds.travelRear,
        title: AppLocale.t('Di chuyển sau'),
        motor: motors[MotorIds.travelRear],
        faultMessage: _motorFaultMessage(MotorIds.travelRear, telemetry.errors),
      ),
    ];
    final steerMotors = [
      _DiagnosticsMotorSpec(
        id: MotorIds.steerFront,
        title: AppLocale.t('Rẽ hướng trước'),
        motor: motors[MotorIds.steerFront],
        faultMessage: _motorFaultMessage(MotorIds.steerFront, telemetry.errors),
      ),
      _DiagnosticsMotorSpec(
        id: MotorIds.steerRear,
        title: AppLocale.t('Rẽ hướng sau'),
        motor: motors[MotorIds.steerRear],
        faultMessage: _motorFaultMessage(MotorIds.steerRear, telemetry.errors),
      ),
    ];
    final hoistMotors = [
      _DiagnosticsMotorSpec(
        id: MotorIds.hoistFront,
        title: AppLocale.t('Nâng hạ trước'),
        motor: motors[MotorIds.hoistFront],
        faultMessage: _motorFaultMessage(MotorIds.hoistFront, telemetry.errors),
      ),
      _DiagnosticsMotorSpec(
        id: MotorIds.hoistRear,
        title: AppLocale.t('Nâng hạ sau'),
        motor: motors[MotorIds.hoistRear],
        faultMessage: _motorFaultMessage(MotorIds.hoistRear, telemetry.errors),
      ),
    ];

    return Padding(
      key: const Key('diagnostics_panel'),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop =
              constraints.maxWidth >= 1000 && constraints.maxHeight >= 560;
          final header = _PanelHeader(
            title: AppLocale.t('Chẩn đoán phần cứng'),
            subtitle: AppLocale.t(
              'Giám sát 6 động cơ và cảm biến an toàn theo thời gian thực',
            ),
            icon: Icons.analytics_outlined,
            trailing: OutlinedButton.icon(
              key: const Key('diagnostics_advanced_control_button'),
              onPressed: () => _showAdvancedControlDialog(context, controller),
              icon: Icon(Icons.tune_rounded, size: 15),
              label: Text(AppLocale.t('ĐIỀU KHIỂN NÂNG CAO')),
            ),
          );

          if (!desktop) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    children: [
                      _DiagnosticsMotorGroup(
                        key: const Key('diagnostics_motion_motors_section'),
                        title: AppLocale.t('Động cơ di chuyển'),
                        icon: Icons.swap_vert_rounded,
                        specs: motionMotors,
                        stackedCards: false,
                      ),
                      const SizedBox(height: 16),
                      _DiagnosticsMotorGroup(
                        key: const Key('diagnostics_steer_motors_section'),
                        title: AppLocale.t('Động cơ rẽ hướng'),
                        icon: Icons.turn_right_rounded,
                        specs: steerMotors,
                        stackedCards: false,
                      ),
                      const SizedBox(height: 16),
                      _DiagnosticsMotorGroup(
                        key: const Key('diagnostics_hoist_motors_section'),
                        title: AppLocale.t('Động cơ nâng hạ'),
                        icon: Icons.vertical_align_top_rounded,
                        specs: hoistMotors,
                        stackedCards: false,
                      ),
                      const SizedBox(height: 16),
                      _ResponsiveDiagnosticsSensorMatrix(
                        controller: controller,
                        desktop: false,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 14),
              Expanded(
                flex: 5,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DiagnosticsMotorGroup(
                        key: const Key('diagnostics_motion_motors_section'),
                        title: AppLocale.t('Động cơ di chuyển'),
                        icon: Icons.swap_vert_rounded,
                        specs: motionMotors,
                        stackedCards: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DiagnosticsMotorGroup(
                        key: const Key('diagnostics_steer_motors_section'),
                        title: AppLocale.t('Động cơ rẽ hướng'),
                        icon: Icons.turn_right_rounded,
                        specs: steerMotors,
                        stackedCards: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DiagnosticsMotorGroup(
                        key: const Key('diagnostics_hoist_motors_section'),
                        title: AppLocale.t('Động cơ nâng hạ'),
                        icon: Icons.vertical_align_top_rounded,
                        specs: hoistMotors,
                        stackedCards: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                flex: 4,
                child: _ResponsiveDiagnosticsSensorMatrix(
                  controller: controller,
                  desktop: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DiagnosticsMotorSpec {
  const _DiagnosticsMotorSpec({
    required this.id,
    required this.title,
    required this.motor,
    this.faultMessage,
  });

  final String id;
  final String title;
  final MotorStatus? motor;
  final String? faultMessage;

  bool get faulted => faultMessage != null;
}

class _DiagnosticsMotorGroup extends StatelessWidget {
  const _DiagnosticsMotorGroup({
    super.key,
    required this.title,
    required this.icon,
    required this.specs,
    required this.stackedCards,
  });

  final String title;
  final IconData icon;
  final List<_DiagnosticsMotorSpec> specs;
  final bool stackedCards;

  @override
  Widget build(BuildContext context) {
    final cards = specs
        .map((spec) => _ResponsiveDiagnosticsMotorCard(spec: spec))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DiagnosticsSectionHeader(icon: icon, title: title),
        const SizedBox(height: 10),
        if (stackedCards)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(height: 10),
                Expanded(child: cards[1]),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final card in cards)
                    SizedBox(
                      width: wide
                          ? (constraints.maxWidth - 10) / 2
                          : constraints.maxWidth,
                      height: 118,
                      child: card,
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _ResponsiveDiagnosticsMotorCard extends StatelessWidget {
  const _ResponsiveDiagnosticsMotorCard({required this.spec});

  final _DiagnosticsMotorSpec spec;

  @override
  Widget build(BuildContext context) {
    final motor = spec.motor;
    final statusColor = _diagnosticMotorColor(motor, faulted: spec.faulted);
    final statusLabel = _diagnosticMotorLabel(motor, faulted: spec.faulted);
    final position = ((motor?.positionM ?? 0.0) * 1000).toStringAsFixed(1);
    final velocity = motorVelocityMps(motor).toStringAsFixed(2);

    return Container(
      key: Key('diagnostics_motor_${spec.id}'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(
                bottom: BorderSide(color: AppColors.surfaceBorder),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    spec.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _MiniStatusPill(
                  key: Key(
                    'diagnostics_motor_${spec.id}_status_${statusLabel.toLowerCase()}',
                  ),
                  label: statusLabel,
                  color: statusColor,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: _DiagnosticsMetricCell(
                      cellKey: Key(
                        'diagnostics_motor_${spec.id}_position_cell',
                      ),
                      label: spec.id.startsWith('hoist')
                          ? AppLocale.t('ĐỘ CAO')
                          : AppLocale.t('VỊ TRÍ'),
                      value: position,
                      unit: 'mm',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DiagnosticsMetricCell(
                      cellKey: Key(
                        'diagnostics_motor_${spec.id}_velocity_cell',
                      ),
                      label: AppLocale.t('VẬN TỐC'),
                      value: velocity,
                      unit: 'm/s',
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsMetricCell extends StatelessWidget {
  const _DiagnosticsMetricCell({
    required this.cellKey,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final Key cellKey;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cellKey,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      unit,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveDiagnosticsSensorMatrix extends StatelessWidget {
  const _ResponsiveDiagnosticsSensorMatrix({
    required this.controller,
    required this.desktop,
  });

  final OhtManualController controller;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final sensors = controller.telemetry.sensors;
    final obstruction = [
      _DiagnosticsSensorSpec.lidar(
        id: 'lidar_upper',
        label: AppLocale.t('Lidar trên'),
        zone: sensors.lidarUpperZone,
      ),
      _DiagnosticsSensorSpec.lidar(
        id: 'lidar_lower',
        label: AppLocale.t('Lidar dưới'),
        zone: sensors.lidarLowerZone,
      ),
      _DiagnosticsSensorSpec.bool(
        id: 'bumper_front',
        label: AppLocale.t('Bumper trước'),
        active: sensors.pumperFront == true,
      ),
      _DiagnosticsSensorSpec.bool(
        id: 'bumper_rear',
        label: AppLocale.t('Bumper sau'),
        active: sensors.pumperRear == true,
      ),
    ];
    final steerLimits = [
      _DiagnosticsSensorSpec.bool(
        id: 'steer_front_left',
        label: AppLocale.t('Rẽ trước trái'),
        active: sensors.steerFrontLeft == true,
      ),
      _DiagnosticsSensorSpec.bool(
        id: 'steer_front_right',
        label: AppLocale.t('Rẽ trước phải'),
        active: sensors.steerFrontRight == true,
      ),
      _DiagnosticsSensorSpec.bool(
        id: 'steer_rear_left',
        label: AppLocale.t('Rẽ sau trái'),
        active: sensors.steerRearLeft == true,
      ),
      _DiagnosticsSensorSpec.bool(
        id: 'steer_rear_right',
        label: AppLocale.t('Rẽ sau phải'),
        active: sensors.steerRearRight == true,
      ),
    ];
    final hoistLimits = [
      _DiagnosticsSensorSpec.bool(
        id: 'hoist_front_upper',
        label: AppLocale.t('Nâng trước trên'),
        active: sensors.hoistFrontUpperLimit == true,
      ),
      _DiagnosticsSensorSpec.bool(
        id: 'hoist_rear_upper',
        label: AppLocale.t('Nâng sau trên'),
        active: sensors.hoistRearUpperLimit == true,
      ),
    ];

    final groups = [
      _DiagnosticsSensorGroup(
        title: AppLocale.t('Cảm biến vật cản'),
        specs: obstruction,
        flex: 4,
      ),
      _DiagnosticsSensorGroup(
        title: AppLocale.t('Giới hạn rẽ hướng'),
        specs: steerLimits,
        flex: 4,
      ),
      _DiagnosticsSensorGroup(
        title: AppLocale.t('Giới hạn nâng hạ'),
        specs: hoistLimits,
        flex: 2,
      ),
    ];

    return Container(
      key: const Key('diagnostics_sensor_matrix'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < groups.length; i++) ...[
                  if (i > 0)
                    Container(width: 1, color: AppColors.surfaceBorder),
                  Expanded(flex: groups[i].flex, child: groups[i]),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < groups.length; i++) ...[
                  groups[i],
                  if (i < groups.length - 1)
                    Divider(color: AppColors.surfaceBorder),
                ],
              ],
            ),
    );
  }
}

class _DiagnosticsSensorGroup extends StatelessWidget {
  const _DiagnosticsSensorGroup({
    required this.title,
    required this.specs,
    required this.flex,
  });

  final String title;
  final List<_DiagnosticsSensorSpec> specs;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillAvailableSpace =
              constraints.hasBoundedHeight && constraints.maxHeight >= 150;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (fillAvailableSpace)
                Expanded(child: _buildFilledSensorGrid())
              else
                _buildWrappedSensorTiles(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilledSensorGrid() {
    final columns = specs.length <= 2 ? 1 : 2;
    final rows = (specs.length / columns).ceil();
    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: 8),
                  Expanded(child: _sensorTileFor(row * columns + column)),
                ],
              ],
            ),
          ),
          if (row < rows - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _sensorTileFor(int index) {
    if (index >= specs.length) {
      return const SizedBox.shrink();
    }
    return _DiagnosticsSensorStatusTile(spec: specs[index], fill: true);
  }

  Widget _buildWrappedSensorTiles() {
    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final spec in specs) _DiagnosticsSensorStatusTile(spec: spec),
        ],
      ),
    );
  }
}

class _DiagnosticsSensorSpec {
  const _DiagnosticsSensorSpec._({
    required this.id,
    required this.label,
    required this.active,
    required this.color,
  });

  factory _DiagnosticsSensorSpec.bool({
    required String id,
    required String label,
    required bool active,
  }) {
    return _DiagnosticsSensorSpec._(
      id: id,
      label: label,
      active: active,
      color: active ? AppColors.warning : AppColors.success,
    );
  }

  factory _DiagnosticsSensorSpec.lidar({
    required String id,
    required String label,
    required LidarZone zone,
  }) {
    return _DiagnosticsSensorSpec._(
      id: id,
      label: label,
      active: zone == LidarZone.warning || zone == LidarZone.danger,
      color: _lidarDiagnosticColor(zone),
    );
  }

  final String id;
  final String label;
  final bool active;
  final Color color;
}

class _DiagnosticsSensorStatusTile extends StatelessWidget {
  const _DiagnosticsSensorStatusTile({required this.spec, this.fill = false});

  final _DiagnosticsSensorSpec spec;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('diagnostics_sensor_${spec.id}'),
      width: fill ? null : 150,
      height: fill ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: fill ? 14 : 10,
        vertical: fill ? 12 : 10,
      ),
      decoration: BoxDecoration(
        color: spec.active
            ? spec.color.withValues(alpha: 0.12)
            : AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: spec.active ? spec.color : AppColors.surfaceBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: fill
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Icon(
            spec.active
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            size: fill ? 20 : 17,
            color: spec.color,
          ),
          SizedBox(width: fill ? 10 : 8),
          Expanded(
            child: Text(
              spec.label,
              maxLines: fill ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: fill ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: fill ? 10 : 6),
          Container(
            width: fill ? 10 : 9,
            height: fill ? 10 : 9,
            decoration: BoxDecoration(
              color: spec.color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _SizedAdvancedControlDialog extends StatelessWidget {
  const _SizedAdvancedControlDialog({required this.controller});

  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width - 48).clamp(360.0, 1180.0).toDouble();
    final gridWidth = dialogWidth - 32;
    final columns = gridWidth >= 980
        ? 3
        : gridWidth >= 640
        ? 2
        : 1;
    final rows = (6 / columns).ceil();
    final aspectRatio = columns == 1 ? 1.18 : 1.38;
    final cardWidth = (gridWidth - (12 * (columns - 1))) / columns;
    final cardHeight = cardWidth / aspectRatio;
    final naturalPanelHeight = 32 + (rows * cardHeight) + (12 * (rows - 1));
    final panelHeight = naturalPanelHeight
        .clamp(260.0, size.height - 160)
        .toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        key: const Key('advanced_control_dialog'),
        width: dialogWidth,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.surfaceBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(
                    bottom: BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocale.t('ĐIỀU KHIỂN NÂNG CAO'),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            AppLocale.t(
                              'Điều khiển riêng 6 động cơ với chiều chạy và vận tốc độc lập',
                            ),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('advanced_control_close_button'),
                      tooltip: AppLocale.t('Đóng'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: panelHeight,
                child: _AdvancedControlPanelV2(controller: controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _StitchDiagnosticsPanel extends StatelessWidget {
  const _StitchDiagnosticsPanel({required this.controller});

  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('diagnostics_panel'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: 'Chẩn đoán phần cứng',
            subtitle: 'Chế độ kiểm tra trực tiếp động cơ và cảm biến',
            icon: Icons.analytics_outlined,
            trailing: OutlinedButton.icon(
              key: const Key('diagnostics_advanced_control_button'),
              onPressed: () => _showAdvancedControlDialog(context, controller),
              icon: Icon(Icons.tune_rounded, size: 15),
              label: Text('ĐIỀU KHIỂN NÂNG CAO'),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: [
                _DiagnosticsSectionHeader(
                  key: const Key('diagnostics_drive_motors_section'),
                  icon: Icons.settings_input_component_rounded,
                  title: 'Động cơ truyền động',
                ),
                const SizedBox(height: 10),
                _DiagnosticsDriveMotorGrid(controller: controller),
                const SizedBox(height: 16),
                _DiagnosticsSectionHeader(
                  key: const Key('diagnostics_hoist_motors_section'),
                  icon: Icons.swap_vert_rounded,
                  title: 'Động cơ nâng hạ',
                ),
                const SizedBox(height: 10),
                _DiagnosticsHoistMotorGrid(controller: controller),
                const SizedBox(height: 16),
                _DiagnosticsSectionHeader(
                  key: const Key('diagnostics_sensor_matrix'),
                  icon: Icons.radar_rounded,
                  title: 'Ma trận cảm biến',
                ),
                const SizedBox(height: 10),
                _DiagnosticsSensorMatrix(controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsSectionHeader extends StatelessWidget {
  const _DiagnosticsSectionHeader({
    super.key,
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.textHint),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: AppColors.surfaceBorder)),
      ],
    );
  }
}

class _DiagnosticsDriveMotorGrid extends StatelessWidget {
  const _DiagnosticsDriveMotorGrid({required this.controller});

  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    final motors = controller.telemetry.motors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        final width = wide
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _DiagnosticsMotorCard(
              width: width,
              title: 'TRÁI TRƯỚC (LF)',
              motor: motors[MotorIds.travelFront],
            ),
            _DiagnosticsMotorCard(
              width: width,
              title: 'PHẢI TRƯỚC (RF)',
              motor: motors[MotorIds.travelFront],
            ),
            _DiagnosticsMotorCard(
              width: width,
              title: 'TRÁI SAU (LR)',
              motor: motors[MotorIds.travelRear],
            ),
            _DiagnosticsMotorCard(
              width: width,
              title: 'PHẢI SAU (RR)',
              motor: motors[MotorIds.travelRear],
            ),
          ],
        );
      },
    );
  }
}

class _DiagnosticsHoistMotorGrid extends StatelessWidget {
  const _DiagnosticsHoistMotorGrid({required this.controller});

  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    final motors = controller.telemetry.motors;
    return Row(
      children: [
        Expanded(
          child: _DiagnosticsMotorCard(
            title: 'TỜI CHÍNH (HOIST 1)',
            motor: motors[MotorIds.hoistFront],
            compact: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DiagnosticsMotorCard(
            title: 'TỜI PHỤ (HOIST 2)',
            motor: motors[MotorIds.hoistRear],
            compact: true,
          ),
        ),
      ],
    );
  }
}

class _DiagnosticsMotorCard extends StatelessWidget {
  const _DiagnosticsMotorCard({
    required this.title,
    required this.motor,
    this.width,
    this.compact = false,
  });

  final String title;
  final MotorStatus? motor;
  final double? width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final statusColor = _diagnosticMotorColor(motor);
    final statusLabel = _diagnosticMotorLabel(motor);
    final position = ((motor?.positionM ?? 0.0) * 1000).toStringAsFixed(1);
    final velocity = motorVelocityMps(motor).toStringAsFixed(2);

    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  bottom: BorderSide(color: AppColors.surfaceBorder),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _MiniStatusPill(label: statusLabel, color: statusColor),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: compact
                  ? Row(
                      children: [
                        Expanded(
                          child: _DiagnosticsValue(
                            label: 'ĐỘ CAO',
                            value: position,
                            unit: 'mm',
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DiagnosticsValue(
                            label: 'VẬN TỐC',
                            value: velocity,
                            unit: 'm/s',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DiagnosticsValue(
                          label: 'VỊ TRÍ',
                          value: position,
                          unit: 'mm',
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        _DiagnosticsValue(
                          label: 'VẬN TỐC',
                          value: velocity,
                          unit: 'm/s',
                          color: AppColors.textPrimary,
                        ),
                        if (motor?.hasWarning == true) ...[
                          const SizedBox(height: 6),
                          Text(
                            motor!.warning!,
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsValue extends StatelessWidget {
  const _DiagnosticsValue({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textHint,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                unit,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DiagnosticsSensorMatrix extends StatelessWidget {
  const _DiagnosticsSensorMatrix({required this.controller});

  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    final sensors = controller.telemetry.sensors;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              key: const Key('diagnostics_lidar_matrix'),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CẢM BIẾN LIDAR',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _DiagnosticsSensorTile(
                        label: 'Phía Trước',
                        color: _lidarDiagnosticColor(sensors.lidarUpperZone),
                        alert: sensors.lidarUpperZone == LidarZone.danger,
                      ),
                      _DiagnosticsSensorTile(
                        label: 'Phía Sau',
                        color: _lidarDiagnosticColor(sensors.lidarLowerZone),
                        alert: sensors.lidarLowerZone == LidarZone.danger,
                      ),
                      _DiagnosticsSensorTile(
                        label: 'Bên Trái',
                        color: sensors.hasLidarDanger
                            ? AppColors.error
                            : AppColors.success,
                        alert: sensors.hasLidarDanger,
                      ),
                      _DiagnosticsSensorTile(
                        label: 'Bên Phải',
                        color: AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 170, color: AppColors.surfaceBorder),
          Expanded(
            child: Padding(
              key: const Key('diagnostics_proximity_matrix'),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CẢM BIẾN TIỆM CẬN',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: SensorIds.boolSensorLabels.entries.map((entry) {
                      final active = sensors.boolValue(entry.key) == true;
                      return _DiagnosticsProximityTile(
                        label: entry.key
                            .split('_')
                            .map((part) => part.substring(0, 1).toUpperCase())
                            .join(),
                        active: active,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsSensorTile extends StatelessWidget {
  const _DiagnosticsSensorTile({
    required this.label,
    required this.color,
    this.alert = false,
  });

  final String label;
  final Color color;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alert ? AppColors.errorBg : AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: alert ? AppColors.error : AppColors.surfaceBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            alert ? Icons.warning_amber_rounded : Icons.explore_outlined,
            size: 18,
            color: alert ? AppColors.error : AppColors.textHint,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: alert ? AppColors.error : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsProximityTile extends StatelessWidget {
  const _DiagnosticsProximityTile({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.warning : AppColors.success;
    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: active ? AppColors.warningBg : AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active ? AppColors.warning : AppColors.surfaceBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? AppColors.warning : AppColors.textHint,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

String _diagnosticMotorLabel(MotorStatus? motor, {bool faulted = false}) {
  if (faulted) return 'ERROR';
  if (motor == null) return 'OFFLINE';
  if (motor.state.name == 'error') return 'ERROR';
  if (motor.hasWarning) return 'WARN';
  if (motor.state.name == 'running') return 'ACTIVE';
  return 'IDLE';
}

Color _diagnosticMotorColor(MotorStatus? motor, {bool faulted = false}) {
  if (faulted) return AppColors.error;
  if (motor == null) return AppColors.textHint;
  if (motor.state.name == 'error') return AppColors.error;
  if (motor.hasWarning) return AppColors.warning;
  if (motor.state.name == 'running') return AppColors.success;
  return AppColors.success;
}

String? _motorFaultMessage(String motorId, List<String> errors) {
  final tokens = switch (motorId) {
    MotorIds.travelFront => [
      'travel_front',
      'travel front',
      'di chuyển trước',
      'di chuyen truoc',
      'động cơ di chuyển trước',
    ],
    MotorIds.travelRear => [
      'travel_rear',
      'travel rear',
      'di chuyển sau',
      'di chuyen sau',
      'động cơ di chuyển sau',
    ],
    MotorIds.steerFront => [
      'steer_front',
      'steer front',
      'rẽ hướng trước',
      're huong truoc',
      'động cơ rẽ hướng trước',
    ],
    MotorIds.steerRear => [
      'steer_rear',
      'steer rear',
      'rẽ hướng sau',
      're huong sau',
      'động cơ rẽ hướng sau',
    ],
    MotorIds.hoistFront => [
      'hoist_front',
      'hoist front',
      'nâng trước',
      'nang truoc',
      'nâng hạ trước',
      'động cơ nâng trước',
    ],
    MotorIds.hoistRear => [
      'hoist_rear',
      'hoist rear',
      'nâng sau',
      'nang sau',
      'nâng hạ sau',
      'động cơ nâng sau',
    ],
    _ => const <String>[],
  };

  for (final error in errors) {
    final normalized = error.toLowerCase();
    final mentionsMotor =
        normalized.contains('motor') ||
        normalized.contains('động cơ') ||
        normalized.contains('dong co');
    if (mentionsMotor && tokens.any(normalized.contains)) {
      return error;
    }
  }
  return null;
}

Color _lidarDiagnosticColor(LidarZone zone) => switch (zone) {
  LidarZone.clear => AppColors.success,
  LidarZone.warning => AppColors.warning,
  LidarZone.danger => AppColors.error,
  LidarZone.noData => AppColors.textHint,
};

// ignore: unused_element
class _DiagnosticsPanel extends StatelessWidget {
  const _DiagnosticsPanel({
    required this.controller,
    required this.onMotorTap,
    required this.onSensorTap,
    required this.onSpeedTap,
  });

  final OhtManualController controller;
  final VoidCallback onMotorTap;
  final VoidCallback onSensorTap;
  final VoidCallback onSpeedTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('diagnostics_panel'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            title: 'Chẩn đoán phần cứng',
            subtitle:
                'Theo dõi động cơ, cảm biến và tốc độ theo thời gian thực',
            icon: Icons.analytics_outlined,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              cacheExtent: 1200,
              children: [
                SizedBox(
                  height: 270,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _MotorStatusBox(
                          controller: controller,
                          large: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: _SensorStatusBox(
                          controller: controller,
                          large: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DiagnosticsActionStrip(
                  onMotorTap: onMotorTap,
                  onSensorTap: onSensorTap,
                  onSpeedTap: onSpeedTap,
                ),
                const SizedBox(height: 12),
                SpeedControlRow(controller: controller),
                const SizedBox(height: 12),
                _AdvancedControlPanel(controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _AdvancedControlDialog extends StatelessWidget {
  const _AdvancedControlDialog({required this.controller});

  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1180,
          maxHeight: size.height - 64,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.surfaceBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(
                    bottom: BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ĐIỀU KHIỂN NÂNG CAO',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Điều khiển riêng 6 động cơ với chiều chạy và vận tốc độc lập',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('advanced_control_close_button'),
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(child: _AdvancedControlPanel(controller: controller)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvancedMotorSpec {
  const _AdvancedMotorSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.forwardLabel,
    required this.reverseLabel,
    required this.forwardIcon,
    required this.reverseIcon,
    required this.forwardType,
    required this.reverseType,
    required this.stopType,
    required this.initialSpeed,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String forwardLabel;
  final String reverseLabel;
  final IconData forwardIcon;
  final IconData reverseIcon;
  final ManualCommandType forwardType;
  final ManualCommandType reverseType;
  final ManualCommandType stopType;
  final int initialSpeed;
}

class _AdvancedControlPanelV2 extends StatelessWidget {
  const _AdvancedControlPanelV2({required this.controller});

  final OhtManualController controller;

  List<_AdvancedMotorSpec> _specs() {
    return [
      _AdvancedMotorSpec(
        id: 'travel_front',
        title: AppLocale.t('Di chuyển trước'),
        subtitle: 'Travel front motor',
        icon: Icons.arrow_upward_rounded,
        forwardLabel: AppLocale.t('Tiến'),
        reverseLabel: AppLocale.t('Lùi'),
        forwardIcon: Icons.north_rounded,
        reverseIcon: Icons.south_rounded,
        forwardType: ManualCommandType.travelFrontForward,
        reverseType: ManualCommandType.travelFrontBackward,
        stopType: ManualCommandType.travelStop,
        initialSpeed: controller.travelSpeed,
      ),
      _AdvancedMotorSpec(
        id: 'travel_rear',
        title: AppLocale.t('Di chuyển sau'),
        subtitle: 'Travel rear motor',
        icon: Icons.arrow_downward_rounded,
        forwardLabel: AppLocale.t('Tiến'),
        reverseLabel: AppLocale.t('Lùi'),
        forwardIcon: Icons.north_rounded,
        reverseIcon: Icons.south_rounded,
        forwardType: ManualCommandType.travelRearForward,
        reverseType: ManualCommandType.travelRearBackward,
        stopType: ManualCommandType.travelStop,
        initialSpeed: controller.travelSpeed,
      ),
      _AdvancedMotorSpec(
        id: 'steer_front',
        title: AppLocale.t('Rẽ hướng trước'),
        subtitle: 'Steer front motor',
        icon: Icons.turn_left_rounded,
        forwardLabel: AppLocale.t('Trái'),
        reverseLabel: AppLocale.t('Phải'),
        forwardIcon: Icons.turn_left_rounded,
        reverseIcon: Icons.turn_right_rounded,
        forwardType: ManualCommandType.steerFrontLeft,
        reverseType: ManualCommandType.steerFrontRight,
        stopType: ManualCommandType.steerStop,
        initialSpeed: controller.steerSpeed,
      ),
      _AdvancedMotorSpec(
        id: 'steer_rear',
        title: AppLocale.t('Rẽ hướng sau'),
        subtitle: 'Steer rear motor',
        icon: Icons.turn_right_rounded,
        forwardLabel: AppLocale.t('Trái'),
        reverseLabel: AppLocale.t('Phải'),
        forwardIcon: Icons.turn_left_rounded,
        reverseIcon: Icons.turn_right_rounded,
        forwardType: ManualCommandType.steerRearLeft,
        reverseType: ManualCommandType.steerRearRight,
        stopType: ManualCommandType.steerStop,
        initialSpeed: controller.steerSpeed,
      ),
      _AdvancedMotorSpec(
        id: 'hoist_front',
        title: AppLocale.t('Nâng hạ trước'),
        subtitle: 'Hoist front motor',
        icon: Icons.vertical_align_top_rounded,
        forwardLabel: AppLocale.t('Nâng'),
        reverseLabel: AppLocale.t('Hạ'),
        forwardIcon: Icons.vertical_align_top_rounded,
        reverseIcon: Icons.vertical_align_bottom_rounded,
        forwardType: ManualCommandType.hoistFrontUp,
        reverseType: ManualCommandType.hoistFrontDown,
        stopType: ManualCommandType.hoistStop,
        initialSpeed: controller.hoistSpeed,
      ),
      _AdvancedMotorSpec(
        id: 'hoist_rear',
        title: AppLocale.t('Nâng hạ sau'),
        subtitle: 'Hoist rear motor',
        icon: Icons.vertical_align_bottom_rounded,
        forwardLabel: AppLocale.t('Nâng'),
        reverseLabel: AppLocale.t('Hạ'),
        forwardIcon: Icons.vertical_align_top_rounded,
        reverseIcon: Icons.vertical_align_bottom_rounded,
        forwardType: ManualCommandType.hoistRearUp,
        reverseType: ManualCommandType.hoistRearDown,
        stopType: ManualCommandType.hoistStop,
        initialSpeed: controller.hoistSpeed,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final specs = _specs();
    return Padding(
      key: const Key('advanced_control_panel'),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 980
              ? 3
              : constraints.maxWidth >= 640
              ? 2
              : 1;
          return GridView.builder(
            itemCount: specs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: crossAxisCount == 1 ? 1.18 : 1.38,
            ),
            itemBuilder: (context, index) {
              return _AdvancedMotorControlCard(
                controller: controller,
                spec: specs[index],
              );
            },
          );
        },
      ),
    );
  }
}

// ignore: unused_element
class _AdvancedControlPanel extends StatelessWidget {
  const _AdvancedControlPanel({required this.controller});

  final OhtManualController controller;

  List<_AdvancedMotorSpec> _specs() {
    return [
      _AdvancedMotorSpec(
        id: 'travel_front',
        title: 'Di chuyển trước',
        subtitle: 'Travel front motor',
        icon: Icons.arrow_upward_rounded,
        forwardLabel: 'Tiến',
        reverseLabel: 'Lùi',
        forwardIcon: Icons.north_rounded,
        reverseIcon: Icons.south_rounded,
        forwardType: ManualCommandType.travelFrontForward,
        reverseType: ManualCommandType.travelFrontBackward,
        stopType: ManualCommandType.travelStop,
        initialSpeed: controller.travelSpeed,
      ),
      _AdvancedMotorSpec(
        id: 'travel_rear',
        title: 'Di chuyển sau',
        subtitle: 'Travel rear motor',
        icon: Icons.arrow_downward_rounded,
        forwardLabel: 'Tiến',
        reverseLabel: 'Lùi',
        forwardIcon: Icons.north_rounded,
        reverseIcon: Icons.south_rounded,
        forwardType: ManualCommandType.travelRearForward,
        reverseType: ManualCommandType.travelRearBackward,
        stopType: ManualCommandType.travelStop,
        initialSpeed: controller.travelSpeed,
      ),
      _AdvancedMotorSpec(
        id: 'hoist_front',
        title: 'Nâng hạ trước',
        subtitle: 'Hoist front motor',
        icon: Icons.vertical_align_top_rounded,
        forwardLabel: 'Nâng',
        reverseLabel: 'Hạ',
        forwardIcon: Icons.vertical_align_top_rounded,
        reverseIcon: Icons.vertical_align_bottom_rounded,
        forwardType: ManualCommandType.hoistFrontUp,
        reverseType: ManualCommandType.hoistFrontDown,
        stopType: ManualCommandType.hoistStop,
        initialSpeed: controller.hoistSpeed,
      ),
      _AdvancedMotorSpec(
        id: 'hoist_rear',
        title: 'Nâng hạ sau',
        subtitle: 'Hoist rear motor',
        icon: Icons.vertical_align_bottom_rounded,
        forwardLabel: 'Nâng',
        reverseLabel: 'Hạ',
        forwardIcon: Icons.vertical_align_top_rounded,
        reverseIcon: Icons.vertical_align_bottom_rounded,
        forwardType: ManualCommandType.hoistRearUp,
        reverseType: ManualCommandType.hoistRearDown,
        stopType: ManualCommandType.hoistStop,
        initialSpeed: controller.hoistSpeed,
      ),
      _AdvancedMotorSpec(
        id: 'steer_front',
        title: 'Rẽ hướng trước',
        subtitle: 'Steer front motor',
        icon: Icons.turn_left_rounded,
        forwardLabel: 'Trái',
        reverseLabel: 'Phải',
        forwardIcon: Icons.turn_left_rounded,
        reverseIcon: Icons.turn_right_rounded,
        forwardType: ManualCommandType.steerFrontLeft,
        reverseType: ManualCommandType.steerFrontRight,
        stopType: ManualCommandType.steerStop,
        initialSpeed: controller.steerSpeed,
      ),
      _AdvancedMotorSpec(
        id: 'steer_rear',
        title: 'Rẽ hướng sau',
        subtitle: 'Steer rear motor',
        icon: Icons.turn_right_rounded,
        forwardLabel: 'Trái',
        reverseLabel: 'Phải',
        forwardIcon: Icons.turn_left_rounded,
        reverseIcon: Icons.turn_right_rounded,
        forwardType: ManualCommandType.steerRearLeft,
        reverseType: ManualCommandType.steerRearRight,
        stopType: ManualCommandType.steerStop,
        initialSpeed: controller.steerSpeed,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final specs = _specs();
    return Padding(
      key: const Key('advanced_control_panel'),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 980
              ? 3
              : constraints.maxWidth >= 640
              ? 2
              : 1;
          return GridView.builder(
            itemCount: specs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: crossAxisCount == 1 ? 1.85 : 1.38,
            ),
            itemBuilder: (context, index) {
              return _AdvancedMotorControlCard(
                controller: controller,
                spec: specs[index],
              );
            },
          );
        },
      ),
    );
  }
}

class _AdvancedMotorControlCard extends StatefulWidget {
  const _AdvancedMotorControlCard({
    required this.controller,
    required this.spec,
  });

  final OhtManualController controller;
  final _AdvancedMotorSpec spec;

  @override
  State<_AdvancedMotorControlCard> createState() =>
      _AdvancedMotorControlCardState();
}

class _AdvancedMotorControlCardState extends State<_AdvancedMotorControlCard> {
  late int _speed;

  @override
  void initState() {
    super.initState();
    _speed = widget.spec.initialSpeed;
  }

  @override
  void didUpdateWidget(covariant _AdvancedMotorControlCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.id != widget.spec.id) {
      _speed = widget.spec.initialSpeed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    return Container(
      key: Key('advanced_motor_${spec.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(spec.icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _MiniStatusPill(label: '$_speed%', color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AdvancedMotorDirectionButton(
                  buttonKey: Key('advanced_motor_${spec.id}_forward'),
                  label: spec.forwardLabel,
                  icon: spec.forwardIcon,
                  command: spec.forwardType,
                  stopCommand: spec.stopType,
                  speed: _speed,
                  controller: widget.controller,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AdvancedMotorDirectionButton(
                  buttonKey: Key('advanced_motor_${spec.id}_reverse'),
                  label: spec.reverseLabel,
                  icon: spec.reverseIcon,
                  command: spec.reverseType,
                  stopCommand: spec.stopType,
                  speed: _speed,
                  controller: widget.controller,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                AppLocale.t('Vận tốc'),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                formatCommandSpeedMps(_speed),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            key: Key('advanced_motor_${spec.id}_slider'),
            min: 0,
            max: 100,
            divisions: 100,
            value: _speed.toDouble(),
            label: '$_speed%',
            onChanged: (value) => setState(() {
              _speed = value.round().clamp(0, 100).toInt();
            }),
          ),
        ],
      ),
    );
  }
}

class _AdvancedMotorDirectionButton extends StatelessWidget {
  const _AdvancedMotorDirectionButton({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.command,
    required this.stopCommand,
    required this.speed,
    required this.controller,
  });

  final Key buttonKey;
  final String label;
  final IconData icon;
  final ManualCommandType command;
  final ManualCommandType stopCommand;
  final int speed;
  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    final blockReason = controller.blockReasonFor(command);
    final enabled = blockReason == null;
    final background = enabled
        ? AppColors.primarySurface
        : AppColors.surfaceBorder;
    final foreground = enabled ? AppColors.primary : AppColors.textHint;
    final border = enabled
        ? AppColors.primary.withValues(alpha: 0.35)
        : AppColors.surfaceBorder;

    return Tooltip(
      message: blockReason ?? '$label $speed%',
      child: Pressable(
        key: buttonKey,
        enabled: enabled,
        onPressStart: enabled
            ? () => controller.sendManualCommand(command, speedOverride: speed)
            : null,
        onPressEnd: enabled
            ? () => controller.sendManualCommand(stopCommand)
            : null,
        pressedScale: 0.97,
        pressedOpacity: 0.76,
        semanticLabel: label,
        child: AnimatedContainer(
          height: 82,
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _LegacyAdvancedControlPanel extends StatelessWidget {
  const _LegacyAdvancedControlPanel({required this.controller});

  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('advanced_control_panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Điều khiển nâng cao',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 330,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: TravelControlBox(controller: controller)),
                const SizedBox(width: 10),
                Expanded(child: HoistControlBox(controller: controller)),
                const SizedBox(width: 10),
                Expanded(child: SteerControlBox(controller: controller)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SystemControlBar(controller: controller),
        ],
      ),
    );
  }
}

enum _LogSeverityFilter { all, info, warning, error }

extension _LogSeverityFilterMeta on _LogSeverityFilter {
  String get key => switch (this) {
    _LogSeverityFilter.all => 'all',
    _LogSeverityFilter.info => 'info',
    _LogSeverityFilter.warning => 'warning',
    _LogSeverityFilter.error => 'error',
  };

  String get label => switch (this) {
    _LogSeverityFilter.all => AppLocale.t('Tất cả'),
    _LogSeverityFilter.info => AppLocale.t('Thông tin'),
    _LogSeverityFilter.warning => AppLocale.t('Cảnh báo'),
    _LogSeverityFilter.error => AppLocale.t('Lỗi/Nghiêm trọng'),
  };

  Color? get color => switch (this) {
    _LogSeverityFilter.warning => AppColors.warning,
    _LogSeverityFilter.error => AppColors.error,
    _ => null,
  };
}

class _LogsPanel extends StatefulWidget {
  const _LogsPanel({required this.controller});

  final OhtManualController controller;

  @override
  State<_LogsPanel> createState() => _LogsPanelState();
}

class _LogsPanelState extends State<_LogsPanel> {
  _LogSeverityFilter _filter = _LogSeverityFilter.all;
  String _search = '';

  bool _matchesFilter(EventSeverity severity) {
    return switch (_filter) {
      _LogSeverityFilter.all => true,
      _LogSeverityFilter.info => severity == EventSeverity.info,
      _LogSeverityFilter.warning => severity == EventSeverity.warning,
      _LogSeverityFilter.error =>
        severity == EventSeverity.critical || severity == EventSeverity.nack,
    };
  }

  bool _matchesSearch(String message) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return true;
    return message.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.controller.events;
    final visibleEvents = events
        .where(
          (event) =>
              _matchesFilter(event.severity) && _matchesSearch(event.message),
        )
        .toList();
    Future<void> downloadLog() async {
      try {
        final file = await EventLogExcelExporter.export(visibleEvents);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocale.t('Đã tải log Excel')}: ${file.path}'),
          ),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocale.t('Không thể tải log Excel')}: $error'),
          ),
        );
      }
    }

    return Padding(
      key: const Key('logs_panel'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: AppLocale.t('Nhật ký hệ thống'),
            subtitle: AppLocale.eventCount(events.length),
            icon: Icons.receipt_long_outlined,
            trailing: OutlinedButton.icon(
              onPressed: widget.controller.clearEvents,
              icon: Icon(Icons.delete_outline_rounded, size: 15),
              label: Text(AppLocale.t('Xóa log')),
            ),
          ),
          const SizedBox(height: 14),
          _LogsToolbar(
            activeFilter: _filter,
            onFilterChanged: (filter) => setState(() => _filter = filter),
            onSearchChanged: (value) => setState(() => _search = value),
            onDownload: downloadLog,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: visibleEvents.isEmpty
                  ? Center(
                      child: Text(
                        AppLocale.t('Không có sự kiện phù hợp'),
                        key: Key('logs_empty_state'),
                        style: TextStyle(color: AppColors.textHint),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: visibleEvents.length,
                      separatorBuilder: (context, index) => Divider(height: 1),
                      itemBuilder: (context, index) {
                        final event = visibleEvents[index];
                        final color = _sevColor(event.severity);
                        final time = event.timestamp;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: index.isEven
                                ? AppColors.surfaceVariant
                                : AppColors.surface,
                            border: Border(
                              left: BorderSide(color: color, width: 3),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 86,
                                child: Text(
                                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: AppColors.textHint,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                width: 86,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  event.severity.name.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  event.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogsToolbar extends StatelessWidget {
  const _LogsToolbar({
    required this.activeFilter,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onDownload,
  });

  final _LogSeverityFilter activeFilter;
  final ValueChanged<_LogSeverityFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('logs_toolbar'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                key: const Key('logs_search_field'),
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: AppLocale.t('Tìm kiếm nhật ký...'),
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: AppColors.surfaceBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            for (final filter in _LogSeverityFilter.values)
              _LogsFilterButton(
                filter: filter,
                active: filter == activeFilter,
                onTap: () => onFilterChanged(filter),
              ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              key: const Key('logs_download_button'),
              onPressed: onDownload,
              icon: Icon(Icons.download_rounded, size: 16),
              label: Text(AppLocale.t('XUẤT NHẬT KÝ')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogsFilterButton extends StatelessWidget {
  const _LogsFilterButton({
    required this.filter,
    required this.active,
    required this.onTap,
  });

  final _LogSeverityFilter filter;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = active
        ? AppColors.textPrimary
        : filter.color ?? AppColors.textSecondary;
    return InkWell(
      key: Key('logs_filter_${filter.key}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        key: active ? Key('logs_filter_${filter.key}_active') : null,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceVariant : AppColors.surface,
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Text(
          filter.label,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.controller,
    required this.username,
    required this.languageCode,
    required this.themeMode,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
    required this.onChangePassword,
    required this.onDisconnect,
  });

  final OhtManualController controller;
  final String username;
  final String languageCode;
  final ThemeMode themeMode;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onChangePassword;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('settings_panel'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: AppLocale.t('Cài đặt hệ thống'),
            subtitle: AppLocale.t('Tài khoản vận hành, kết nối và giao diện'),
            icon: Icons.tune_outlined,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _SettingsCardGrid(
              controller: controller,
              username: username,
              languageCode: languageCode,
              themeMode: themeMode,
              onLanguageChanged: onLanguageChanged,
              onThemeModeChanged: onThemeModeChanged,
              onChangePassword: onChangePassword,
              onDisconnect: onDisconnect,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCardGrid extends StatelessWidget {
  const _SettingsCardGrid({
    required this.controller,
    required this.username,
    required this.languageCode,
    required this.themeMode,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
    required this.onChangePassword,
    required this.onDisconnect,
  });

  final OhtManualController controller;
  final String username;
  final String languageCode;
  final ThemeMode themeMode;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onChangePassword;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    final general = _buildGeneralCard();
    final user = _buildUserCard();
    final firmware = _buildFirmwareCard();
    final session = _buildSessionCard();
    final actionBar = _buildActionBar();

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 980;
        if (!twoColumns) {
          return ListView(
            key: const Key('settings_bento_grid'),
            cacheExtent: 1600,
            children: [
              general,
              const SizedBox(height: 12),
              user,
              const SizedBox(height: 12),
              firmware,
              const SizedBox(height: 12),
              session,
              const SizedBox(height: 12),
              actionBar,
            ],
          );
        }

        return SingleChildScrollView(
          key: const Key('settings_bento_grid'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                key: const Key('settings_two_column_grid'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      key: const Key('settings_left_column'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [general, const SizedBox(height: 12), user],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      key: const Key('settings_right_column'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [firmware, const SizedBox(height: 12), session],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              actionBar,
            ],
          ),
        );
      },
    );
  }

  Widget _buildGeneralCard() {
    return _SettingsCard(
      key: const Key('settings_general_panel'),
      title: AppLocale.t('Hệ thống chung'),
      icon: Icons.settings_outlined,
      children: [
        _SettingsRow(label: AppLocale.t('Định danh đơn vị'), value: '402-B'),
        _SettingsOptionGroup(
          label: AppLocale.t('Ngôn ngữ giao diện'),
          children: [
            _SettingsOptionButton(
              buttonKey: const Key('settings_language_vi_button'),
              activeKey: const Key('settings_language_vi_active'),
              label: AppLocale.t('Tiếng Việt'),
              active: languageCode == 'vi',
              onTap: () => onLanguageChanged('vi'),
            ),
            _SettingsOptionButton(
              buttonKey: const Key('settings_language_en_button'),
              activeKey: const Key('settings_language_en_active'),
              label: 'English',
              active: languageCode == 'en',
              onTap: () => onLanguageChanged('en'),
            ),
          ],
        ),
        _SettingsOptionGroup(
          label: AppLocale.t('Giao diện'),
          children: [
            _SettingsOptionButton(
              buttonKey: const Key('settings_theme_light_button'),
              activeKey: const Key('settings_theme_light_active'),
              label: AppLocale.t('Sáng'),
              active: themeMode != ThemeMode.dark,
              onTap: () => onThemeModeChanged(ThemeMode.light),
            ),
            _SettingsOptionButton(
              buttonKey: const Key('settings_theme_dark_button'),
              activeKey: const Key('settings_theme_dark_active'),
              label: AppLocale.t('Tối'),
              active: themeMode == ThemeMode.dark,
              onTap: () => onThemeModeChanged(ThemeMode.dark),
            ),
          ],
        ),
        _SettingsRow(label: AppLocale.t('Múi giờ'), value: 'UTC +07:00 (ICT)'),
        _SettingsRow(
          label: AppLocale.t('Giao thức'),
          value: controller.protocol.label,
        ),
      ],
    );
  }

  Widget _buildUserCard() {
    return _SettingsCard(
      key: const Key('settings_user_panel'),
      title: AppLocale.t('Thông tin vận hành'),
      icon: Icons.account_circle_outlined,
      children: [
        _SettingsRow(label: AppLocale.t('Người vận hành'), value: username),
        _SettingsRow(
          label: AppLocale.t('Giao thức'),
          value: controller.protocol.label,
        ),
        _SettingsRow(label: 'Endpoint', value: controller.activeEndpoint),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onChangePassword,
            icon: Icon(Icons.lock_reset_rounded, size: 16),
            label: Text(AppLocale.t('Đổi mật khẩu')),
          ),
        ),
      ],
    );
  }

  Widget _buildFirmwareCard() {
    return _SettingsCard(
      key: const Key('settings_firmware_panel'),
      title: AppLocale.t('Cập nhật firmware'),
      icon: Icons.system_update_alt_rounded,
      children: [
        _SettingsRow(label: AppLocale.t('Phiên bản hiện tại'), value: 'v2.4.1'),
        _SettingsRow(
          label: AppLocale.t('Trạng thái'),
          value: AppLocale.t('Đã cập nhật'),
        ),
        _SettingsRow(
          label: AppLocale.t('Kênh phát hành'),
          value: AppLocale.t('Ổn định'),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 1,
            minHeight: 8,
            backgroundColor: AppColors.surfaceVariant,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.sync_rounded, size: 16),
            label: Text(AppLocale.t('Kiểm tra cập nhật')),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionCard() {
    return _SettingsCard(
      key: const Key('settings_session_panel'),
      title: AppLocale.t('Phiên làm việc'),
      icon: Icons.link_off_rounded,
      children: [
        Text(
          AppLocale.t('Ngắt kết nối để quay lại màn cấu hình giao thức.'),
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onDisconnect,
            icon: Icon(Icons.link_off_rounded, size: 16),
            label: Text(AppLocale.t('Ngắt kết nối')),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return Container(
      key: const Key('settings_action_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            key: const Key('settings_cancel_button'),
            onPressed: () {},
            child: Text(AppLocale.t('HỦY BỎ THAY ĐỔI')),
          ),
          const SizedBox(width: 12),
          FilledButton(
            key: const Key('settings_apply_button'),
            onPressed: () {},
            child: Text(AppLocale.t('ÁP DỤNG CẤU HÌNH')),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primarySurfaceLight,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _DiagnosticsActionStrip extends StatelessWidget {
  const _DiagnosticsActionStrip({
    required this.onMotorTap,
    required this.onSensorTap,
    required this.onSpeedTap,
  });

  final VoidCallback onMotorTap;
  final VoidCallback onSensorTap;
  final VoidCallback onSpeedTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onMotorTap,
            icon: Icon(Icons.memory_rounded, size: 15),
            label: Text('Động cơ'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onSensorTap,
            icon: Icon(Icons.sensors_rounded, size: 15),
            label: Text('Cảm biến'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onSpeedTap,
            icon: Icon(Icons.speed_rounded, size: 15),
            label: Text('Tốc độ'),
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsOptionGroup extends StatelessWidget {
  const _SettingsOptionGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: children)),
        ],
      ),
    );
  }
}

class _SettingsOptionButton extends StatelessWidget {
  const _SettingsOptionButton({
    required this.buttonKey,
    required this.activeKey,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final Key buttonKey;
  final Key activeKey;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      key: buttonKey,
      onTap: active ? null : onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        key: active ? activeKey : null,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
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
                style: TextStyle(
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
                  Icon(
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
                decoration: BoxDecoration(
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
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
                  style: TextStyle(
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
                    style: TextStyle(
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
  const _MotorStatusBox({required this.controller, this.large = false});

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
  const _SensorStatusBox({required this.controller, this.large = false});

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
// ignore: unused_element
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
          Icon(
            Icons.precision_manufacturing_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_rounded, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text(
                    'DỪNG KHẨN CẤP',
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
                Icon(
                  Icons.account_circle_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  username,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: onDisconnect,
            icon: Icon(Icons.link_off_rounded, color: Colors.white70, size: 14),
            label: Text(
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
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(widget.parentContext);
    await AuthStorage.setPassword(newPwd);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Đã cập nhật mật khẩu.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Đổi mật khẩu'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _oldCtrl,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: 'Mật khẩu cũ'),
              onChanged: (_) => setState(() => _errorText = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCtrl,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: 'Mật khẩu mới'),
              onChanged: (_) => setState(() => _errorText = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: 'Nhập lại mật khẩu mới'),
              onChanged: (_) => setState(() => _errorText = null),
              onSubmitted: (_) => _save(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  style: TextStyle(
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
          child: Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Lưu'),
        ),
      ],
    );
  }
}

// ignore: unused_element
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
            style: TextStyle(
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
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
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
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
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
                  ? Center(
                      child: Text(
                        'Không có sự kiện',
                        style: TextStyle(color: AppColors.textHint),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: events.length,
                      separatorBuilder: (context, index) => Divider(height: 1),
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
                                style: TextStyle(
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
                                  style: TextStyle(
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
            Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _downloadLog,
                    icon: Icon(Icons.download_rounded, size: 13),
                    label: Text('Tải xuống Excel'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      textStyle: TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.controller.clearEvents();
                    },
                    icon: Icon(Icons.delete_outline_rounded, size: 13),
                    label: Text('Xóa log'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 32),
                      textStyle: TextStyle(fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      textStyle: TextStyle(fontSize: 11),
                    ),
                    child: Text('Đóng'),
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
