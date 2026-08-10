import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/oht_ids.dart';
import '../../../../core/enums/connection_phase.dart';
import '../../../../core/enums/event_severity.dart';
import '../../../../core/enums/lidar_zone.dart';
import '../../../../core/enums/manual_command_type.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_locale.dart';
import '../../../../core/utils/app_update_service.dart';
import '../../../../core/utils/auth_storage.dart';
import '../../../../core/widgets/pressable.dart';

import '../../data/services/event_log_excel_exporter.dart';
import '../../domain/entities/motor_status.dart';
import '../../domain/entities/oht_telemetry.dart';
import '../controllers/oht_manual_controller.dart';
import '../widgets/emergency_alert_frame.dart';
import '../widgets/industrial_top_bar.dart';
import '../widgets/motor_display_formatters.dart';

class OhtManualScreen extends StatefulWidget {
  const OhtManualScreen({
    required this.controller,
    required this.username,
    this.userRole = 1,
    required this.activeItem,
    required this.languageCode,
    required this.themeMode,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
    required this.onTopNavSelected,
    this.onOpenUserManagement,
    required this.onDisconnect,
    required this.onLogout,
    super.key,
  });
  final OhtManualController controller;
  final String username;
  final int userRole;
  final IndustrialTopBarItem activeItem;
  final String languageCode;
  final ThemeMode themeMode;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<IndustrialTopBarItem> onTopNavSelected;
  final VoidCallback? onOpenUserManagement;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onLogout;
  @override
  State<OhtManualScreen> createState() => _OhtManualScreenState();
}

class _OhtManualScreenState extends State<OhtManualScreen> {
  Timer? _pollTimer;
  int _lastRevision = -1;
  AppVersionInfo? _availableUpdate;

  @override
  void initState() {
    super.initState();
    widget.controller.setOperator(widget.username);
    widget.controller.setUserRole(widget.userRole);
    _pollTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final rev = widget.controller.revision;
      if (rev != _lastRevision) {
        _lastRevision = rev;
        if (mounted) setState(() {});
      }
    });
    _checkForAppUpdates();
  }

  @override
  void didUpdateWidget(covariant OhtManualScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userRole != widget.userRole) {
      widget.controller.setUserRole(widget.userRole);
    }
    if (oldWidget.username != widget.username) {
      widget.controller.setOperator(widget.username);
    }
  }

  Future<void> _checkForAppUpdates() async {
    final info = await AppUpdateService.checkForUpdates();
    if (mounted && info != null && info.isUpdateAvailable) {
      setState(() {
        _availableUpdate = info;
      });
    }
  }

  void _showUpdateDialog(AppVersionInfo info) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: AppColors.warning),
            const SizedBox(width: 8),
            Text('Cập nhật v${info.latestVersion}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Đã có bản cập nhật mới cho ứng dụng OHT!'),
            const SizedBox(height: 8),
            Text('Phiên bản mới: v${info.latestVersion}'),
            const SizedBox(height: 12),
            const Text('Nội dung cập nhật:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(info.releaseNotes, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Để sau'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _startDirectUpdateDownload(info);
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('Cập nhật ngay'),
          ),
        ],
      ),
    );
  }

  void _startDirectUpdateDownload(AppVersionInfo info) {
    final downloadUrl = AppUpdateService.getDownloadUrl(info, defaultTargetPlatform);

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang cập nhật phiên bản Web... Vui lòng chờ vài giây')),
      );
      AppUpdateService.openDownloadUrl(downloadUrl);
      return;
    }

    double downloadProgress = 0.0;
    String statusText = 'Đang kết nối server...';
    StateSetter? dialogSetState;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (progressContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          dialogSetState = setDialogState;
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.downloading_rounded, color: AppColors.info),
                const SizedBox(width: 8),
                const Text('Đang tải bản cập nhật...'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: downloadProgress > 0 ? downloadProgress : null),
                const SizedBox(height: 12),
                Text(statusText, style: const TextStyle(fontSize: 13)),
              ],
            ),
          );
        },
      ),
    );

    AppUpdateService.downloadInstallerFile(
      downloadUrl: downloadUrl,
      onProgress: (progress, bytesText) {
        if (dialogSetState != null) {
          dialogSetState!(() {
            downloadProgress = progress;
            statusText = 'Đã tải ${(progress * 100).toStringAsFixed(0)}% ($bytesText)';
          });
        }
      },
    ).then((file) async {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (file != null) {
        final success = await AppUpdateService.launchInstaller(file);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể tự chạy installer. Đang mở trình duyệt thay thế...')),
          );
          await AppUpdateService.openDownloadUrl(downloadUrl);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang mở trang phát hành để bạn tải bộ cài mới...')),
        );
        await AppUpdateService.openDownloadUrl(downloadUrl);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
      builder: (_) => const _ChangePasswordDialog(),
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
    ctrl.setOperator(widget.username);
    final esActive = ctrl.emergencyStopActive;
    final (connectionLabel, connectionColor) = _connectionStatusMeta(
      ctrl.connectionStatus.phase,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.space): () {
            ctrl.sendManualCommand(ManualCommandType.emergencyStop);
            if (mounted) setState(() {});
          },
          const SingleActivator(LogicalKeyboardKey.escape): () {
            ctrl.sendManualCommand(ManualCommandType.emergencyStop);
            if (mounted) setState(() {});
          },
          const SingleActivator(LogicalKeyboardKey.keyW): () {
            if (ctrl.blockReasonFor(ManualCommandType.hoistUp) == null) {
              ctrl.sendManualCommand(ManualCommandType.hoistUp);
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowUp): () {
            if (ctrl.blockReasonFor(ManualCommandType.hoistUp) == null) {
              ctrl.sendManualCommand(ManualCommandType.hoistUp);
            }
          },
          const SingleActivator(LogicalKeyboardKey.keyS): () {
            if (ctrl.blockReasonFor(ManualCommandType.hoistDown) == null) {
              ctrl.sendManualCommand(ManualCommandType.hoistDown);
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowDown): () {
            if (ctrl.blockReasonFor(ManualCommandType.hoistDown) == null) {
              ctrl.sendManualCommand(ManualCommandType.hoistDown);
            }
          },
          const SingleActivator(LogicalKeyboardKey.keyA): () {
            if (ctrl.blockReasonForUnifiedSteer(left: true) == null) {
              ctrl.sendUnifiedSteer(left: true);
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            if (ctrl.blockReasonForUnifiedSteer(left: true) == null) {
              ctrl.sendUnifiedSteer(left: true);
            }
          },
          const SingleActivator(LogicalKeyboardKey.keyD): () {
            if (ctrl.blockReasonForUnifiedSteer(left: false) == null) {
              ctrl.sendUnifiedSteer(left: false);
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            if (ctrl.blockReasonForUnifiedSteer(left: false) == null) {
              ctrl.sendUnifiedSteer(left: false);
            }
          },
          const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () {
            widget.onTopNavSelected(IndustrialTopBarItem.dashboard);
          },
          const SingleActivator(LogicalKeyboardKey.digit1, control: true): () {
            widget.onTopNavSelected(IndustrialTopBarItem.dashboard);
          },
          const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () {
            widget.onTopNavSelected(IndustrialTopBarItem.diagnostics);
          },
          const SingleActivator(LogicalKeyboardKey.digit2, control: true): () {
            widget.onTopNavSelected(IndustrialTopBarItem.diagnostics);
          },
          const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () {
            widget.onTopNavSelected(IndustrialTopBarItem.logs);
          },
          const SingleActivator(LogicalKeyboardKey.digit3, control: true): () {
            widget.onTopNavSelected(IndustrialTopBarItem.logs);
          },
          const SingleActivator(LogicalKeyboardKey.digit4, meta: true): () {
            widget.onTopNavSelected(IndustrialTopBarItem.settings);
          },
          const SingleActivator(LogicalKeyboardKey.digit4, control: true): () {
            widget.onTopNavSelected(IndustrialTopBarItem.settings);
          },
          const SingleActivator(LogicalKeyboardKey.keyL, meta: true): () {
            if (ctrl.isConnected) {
              widget.onDisconnect();
            } else {
              widget.onLogout();
            }
          },
          const SingleActivator(LogicalKeyboardKey.keyL, control: true): () {
            if (ctrl.isConnected) {
              widget.onDisconnect();
            } else {
              widget.onLogout();
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: EmergencyAlertFrame(
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
                  updateAvailable: _availableUpdate != null,
                  onUpdateTap: () {
                    if (_availableUpdate != null) {
                      _showUpdateDialog(_availableUpdate!);
                    }
                  },
                  onItemSelected: widget.onTopNavSelected,
                  onEmergencyPressed: () {
                    ctrl.sendManualCommand(ManualCommandType.emergencyStop);
                    if (mounted) setState(() {});
                  },
                  onUserTap: _showChangePasswordPanel,
                  onExit: () {
                    if (ctrl.isConnected) {
                      widget.onDisconnect();
                    } else {
                      widget.onLogout();
                    }
                  },
                  exitLabel: ctrl.isConnected
                      ? AppLocale.t('Ngắt kết nối')
                      : AppLocale.t('Đăng xuất'),
                  exitIcon: ctrl.isConnected
                      ? Icons.link_off_rounded
                      : Icons.logout_rounded,
                ),
                // ─── Body ───
                Expanded(
                  child: switch (widget.activeItem) {
                    IndustrialTopBarItem.dashboard => _DashboardPanel(
                      controller: ctrl,
                      userRole: widget.userRole,
                      onSpeedTap: _showSpeedPanel,
                    ),
                    IndustrialTopBarItem.diagnostics => _ResponsiveDiagnosticsPanel(
                      controller: ctrl,
                    ),
                    IndustrialTopBarItem.logs => _LogsPanel(controller: ctrl),
                    IndustrialTopBarItem.settings => _SettingsPanel(
                      controller: ctrl,
                      username: widget.username,
                      userRole: widget.userRole,
                      languageCode: widget.languageCode,
                      themeMode: widget.themeMode,
                      onLanguageChanged: widget.onLanguageChanged,
                      onThemeModeChanged: widget.onThemeModeChanged,
                      onChangePassword: _showChangePasswordPanel,
                      onOpenUserManagement: widget.onOpenUserManagement,
                      onDisconnect: widget.onDisconnect,
                      onLogout: widget.onLogout,
                    ),
                    IndustrialTopBarItem.connection => const SizedBox.shrink(),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.controller,
    this.userRole = 1,
    required this.onSpeedTap,
  });

  final OhtManualController controller;
  final int userRole;
  final VoidCallback onSpeedTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('dashboard_panel'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (userRole == 2)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility, color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocale.t('Chế độ chỉ giám sát (Viewer Mode) - Quyền hạn tài khoản hiện tại không cho phép thao tác điều khiển thiết bị.'),
                      style: TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          _Utf8DashboardTelemetryStrip(
            controller: controller,
            onSpeedTap: onSpeedTap,
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
  });

  final OhtManualController controller;
  final VoidCallback onSpeedTap;

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
              value: '${t.positionX.toStringAsFixed(1)}m',
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
            child: _DashboardMetric(
              key: const Key('dashboard_metric_errors'),
              label: AppLocale.t('LỖI'),
              value: t.errors.isEmpty ? '0' : '${t.errors.length}',
              color: t.errors.isEmpty ? AppColors.success : AppColors.error,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 950) {
          final items = [
            _Utf8DashboardStatusMetric(
              connected: t.connected,
              label: t.connected
                  ? AppLocale.t('Trực tuyến')
                  : AppLocale.t('Ngoại tuyến'),
            ),
            _DashboardMetric(
              label: AppLocale.t('CHẾ ĐỘ'),
              value: t.mode.name.toUpperCase(),
              color: AppColors.textPrimary,
            ),
            _DashboardBatteryMetric(
              batteryLevel: t.batteryLevel,
              isCharging: t.isCharging,
            ),
            _DashboardMetric(
              label: AppLocale.t('TỌA ĐỘ'),
              value: '${t.positionX.toStringAsFixed(1)}m',
              color: AppColors.primary,
            ),
            _DashboardMetric(
              key: const Key('dashboard_metric_z'),
              label: AppLocale.t('VỊ TRÍ Z'),
              value: '${(zPosition * 1000).toStringAsFixed(0)} mm',
              color: AppColors.primary,
            ),
            Pressable(
              onTap: onSpeedTap,
              pressedScale: 0.98,
              child: _DashboardMetric(
                label: AppLocale.t('TỐC ĐỘ'),
                value: formatTravelVelocityMps(t),
                color: AppColors.textPrimary,
              ),
            ),
            _DashboardMetric(
              key: const Key('dashboard_metric_errors'),
              label: AppLocale.t('LỖI'),
              value: t.errors.isEmpty ? '0' : '${t.errors.length}',
              color: t.errors.isEmpty ? AppColors.success : AppColors.error,
            ),
            _DashboardMetric(
              key: const Key('dashboard_metric_steering'),
              label: AppLocale.t('HƯỚNG LÁI'),
              value: steeringState,
              color: AppColors.textPrimary,
            ),
            _DashboardMetric(
              label: AppLocale.t('TRẠNG THÁI'),
              value: sensorState,
              color: sensorState == 'OK'
                  ? AppColors.success
                  : sensorState == AppLocale.t('CẢNH BÁO')
                  ? AppColors.warning
                  : AppColors.error,
            ),
          ];

          final columns = constraints.maxWidth < 550 ? 2 : 3;

          return Container(
            key: const Key('dashboard_telemetry_strip'),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                mainAxisExtent: 64,
              ),
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.surfaceBorder.withValues(alpha: 0.6),
                    ),
                  ),
                  child: items[index],
                );
              },
            ),
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
          child: content(),
        );
      },
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


class _DashboardTelemetrySlot extends StatelessWidget {
  const _DashboardTelemetrySlot({required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(flex: flex, child: child);
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
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
              Text(
                '$batteryLevel%',
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

// ─── Motor Status Box (removed — unified controls only) ─────────────────────

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
    final velocity = motorVelocityRpm(motor).toInt().toString();

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
                      unit: 'RPM',
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


class _DiagnosticsSectionHeader extends StatelessWidget {
  const _DiagnosticsSectionHeader({
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
  DateTime? _startDate;
  DateTime? _endDate;

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

  bool _matchesDateRange(DateTime timestamp) {
    if (_startDate != null) {
      final startOfDay = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      if (timestamp.isBefore(startOfDay)) return false;
    }
    if (_endDate != null) {
      final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59, 999);
      if (timestamp.isAfter(endOfDay)) return false;
    }
    return true;
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: AppLocale.t('Chọn từ ngày'),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: AppLocale.t('Chọn đến ngày'),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.controller.events;
    final visibleEvents = events
        .where(
          (event) =>
              _matchesFilter(event.severity) &&
              _matchesSearch(event.message) &&
              _matchesDateRange(event.timestamp),
        )
        .toList();
    Future<void> downloadLog() async {
      try {
        await EventLogExcelExporter.export(visibleEvents);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.t('Xuất file nhật ký Excel thành công.')),
          ),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.t('Không thể xuất file nhật ký Excel. Vui lòng thử lại.')),
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
            startDate: _startDate,
            endDate: _endDate,
            onFilterChanged: (filter) => setState(() => _filter = filter),
            onSearchChanged: (value) => setState(() => _search = value),
            onSelectStartDate: _selectStartDate,
            onSelectEndDate: _selectEndDate,
            onClearDateFilter: () => setState(() {
              _startDate = null;
              _endDate = null;
            }),
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
                          child: LayoutBuilder(
                            builder: (context, itemConstraints) {
                              final itemRow = Row(
                                children: [
                                  SizedBox(
                                    width: 135,
                                    child: Text(
                                      '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: AppColors.textHint,
                                        fontSize: 10,
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
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 90,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceBorder.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          event.operator == 'System'
                                              ? Icons.smart_toy_outlined
                                              : Icons.person_outline_rounded,
                                          size: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            event.operator,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
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
                              );

                              if (itemConstraints.maxWidth < 600) {
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(width: 600, child: itemRow),
                                );
                              }
                              return itemRow;
                            },
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
    required this.startDate,
    required this.endDate,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onClearDateFilter,
    required this.onDownload,
  });

  final _LogSeverityFilter activeFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<_LogSeverityFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final VoidCallback onClearDateFilter;
  final Future<void> Function() onDownload;

  String _formatDateLabel(DateTime? dt, String defaultLabel) {
    if (dt == null) return defaultLabel;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasDateFilter = startDate != null || endDate != null;

    final dateButtons = [
      OutlinedButton.icon(
        onPressed: onSelectStartDate,
        icon: Icon(
          Icons.calendar_today_rounded,
          size: 14,
          color: startDate != null ? AppColors.primary : AppColors.textSecondary,
        ),
        label: Text(
          'Từ: ${_formatDateLabel(startDate, 'Chọn ngày')}',
          style: TextStyle(
            fontSize: 11,
            color: startDate != null ? AppColors.primary : AppColors.textSecondary,
            fontWeight: startDate != null ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
      OutlinedButton.icon(
        onPressed: onSelectEndDate,
        icon: Icon(
          Icons.event_rounded,
          size: 14,
          color: endDate != null ? AppColors.primary : AppColors.textSecondary,
        ),
        label: Text(
          'Đến: ${_formatDateLabel(endDate, 'Chọn ngày')}',
          style: TextStyle(
            fontSize: 11,
            color: endDate != null ? AppColors.primary : AppColors.textSecondary,
            fontWeight: endDate != null ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
      if (hasDateFilter)
        IconButton(
          onPressed: onClearDateFilter,
          tooltip: AppLocale.t('Xóa lọc ngày'),
          icon: const Icon(Icons.clear_rounded, size: 16),
          color: AppColors.error,
        ),
    ];

    return Container(
      key: const Key('logs_toolbar'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 980) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('logs_search_field'),
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: AppLocale.t('Tìm kiếm nhật ký...'),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: AppColors.surfaceBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final filter in _LogSeverityFilter.values)
                      _LogsFilterButton(
                        filter: filter,
                        active: filter == activeFilter,
                        onTap: () => onFilterChanged(filter),
                      ),
                    ...dateButtons,
                    OutlinedButton.icon(
                      key: const Key('logs_download_button'),
                      onPressed: onDownload,
                      icon: const Icon(Icons.download_rounded, size: 15),
                      label: Text(AppLocale.t('XUẤT NHẬT KÝ')),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  key: const Key('logs_search_field'),
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: AppLocale.t('Tìm kiếm nhật ký...'),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
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
              const SizedBox(width: 8),
              for (final filter in _LogSeverityFilter.values) ...[
                _LogsFilterButton(
                  filter: filter,
                  active: filter == activeFilter,
                  onTap: () => onFilterChanged(filter),
                ),
                const SizedBox(width: 4),
              ],
              const SizedBox(width: 8),
              ...dateButtons,
              const Spacer(),
              OutlinedButton.icon(
                key: const Key('logs_download_button'),
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(AppLocale.t('XUẤT NHẬT KÝ')),
              ),
            ],
          );
        },
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
    this.userRole = 1,
    required this.languageCode,
    required this.themeMode,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
    required this.onChangePassword,
    this.onOpenUserManagement,
    required this.onDisconnect,
    required this.onLogout,
  });

  final OhtManualController controller;
  final String username;
  final int userRole;
  final String languageCode;
  final ThemeMode themeMode;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onChangePassword;
  final VoidCallback? onOpenUserManagement;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onLogout;

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
              userRole: userRole,
              languageCode: languageCode,
              themeMode: themeMode,
              onLanguageChanged: onLanguageChanged,
              onThemeModeChanged: onThemeModeChanged,
              onChangePassword: onChangePassword,
              onOpenUserManagement: onOpenUserManagement,
              onDisconnect: onDisconnect,
              onLogout: onLogout,
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
    this.userRole = 1,
    required this.languageCode,
    required this.themeMode,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
    required this.onChangePassword,
    this.onOpenUserManagement,
    required this.onDisconnect,
    required this.onLogout,
  });

  final OhtManualController controller;
  final String username;
  final int userRole;
  final String languageCode;
  final ThemeMode themeMode;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onChangePassword;
  final VoidCallback? onOpenUserManagement;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final general = _buildGeneralCard();
    final user = _buildUserCard();
    final webHealth = _buildSystemHealthCard();
    final session = _buildSessionCard();
    final actionBar = _buildActionBar();

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 980;
        if (!twoColumns) {
          return ListView(
            key: const Key('settings_bento_grid'),
            scrollCacheExtent: const ScrollCacheExtent.pixels(1600),
            children: [
              general,
              const SizedBox(height: 12),
              user,
              const SizedBox(height: 12),
              webHealth,
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
                      children: [webHealth, const SizedBox(height: 12), session],
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
        _SettingsRow(label: AppLocale.t('Định danh đơn vị'), value: AppConstants.unitId),
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
    final roleLabel = switch (userRole) {
      0 => '0 - Admin (Quản trị viên)',
      1 => '1 - Điều khiển (Operator)',
      2 => '2 - Chỉ giám sát (Viewer)',
      _ => 'User',
    };

    return _SettingsCard(
      key: const Key('settings_user_panel'),
      title: AppLocale.t('Thông tin vận hành'),
      icon: Icons.account_circle_outlined,
      children: [
        _SettingsRow(label: AppLocale.t('Người vận hành'), value: username),
        _SettingsRow(label: AppLocale.t('Phân quyền'), value: roleLabel),
        _SettingsRow(
          label: AppLocale.t('Giao thức'),
          value: controller.protocol.label,
        ),
        _SettingsRow(label: 'Endpoint', value: controller.activeEndpoint),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onChangePassword,
              icon: const Icon(Icons.lock_reset_rounded, size: 16),
              label: Text(AppLocale.t('Đổi mật khẩu')),
            ),
            if (kIsWeb && userRole == 0 && onOpenUserManagement != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: onOpenUserManagement,
                icon: const Icon(Icons.manage_accounts, size: 16),
                label: Text(AppLocale.t('Quản lý tài khoản (Admin)')),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSystemHealthCard() {
    return _SettingsCard(
      key: const Key('settings_system_health_panel'),
      title: AppLocale.t('Trạng thái Web & Offline PWA'),
      icon: Icons.health_and_safety_outlined,
      children: [
        _SettingsRow(
          label: AppLocale.t('Ứng dụng Web PWA'),
          value: AppLocale.t('Sẵn sàng Offline'),
        ),
        _SettingsRow(
          label: AppLocale.t('Service Worker'),
          value: AppLocale.t('Hoạt động (Cache v15)'),
        ),
        _SettingsRow(
          label: AppLocale.t('Gói tài nguyên Web'),
          value: AppLocale.t('Đã nạp 100%'),
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
          child: Builder(
            builder: (context) {
              return OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocale.t('Ứng dụng đã sẵn sàng hoạt động ngoại tuyến (Offline)!'),
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                icon: const Icon(Icons.verified_outlined, size: 16),
                label: Text(AppLocale.t('Kiểm tra PWA Offline')),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSessionCard() {
    final isConnected = controller.isConnected;
    return _SettingsCard(
      key: const Key('settings_session_panel'),
      title: AppLocale.t('Phiên làm việc'),
      icon: isConnected ? Icons.link_off_rounded : Icons.logout_rounded,
      children: [
        Text(
          isConnected
              ? AppLocale.t('Ngắt kết nối để quay lại màn cấu hình giao thức.')
              : AppLocale.t('Đăng xuất khỏi tài khoản hệ thống.'),
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
            onPressed: isConnected ? onDisconnect : onLogout,
            icon: Icon(
              isConnected ? Icons.link_off_rounded : Icons.logout_rounded,
              size: 16,
            ),
            label: Text(
              isConnected
                  ? AppLocale.t('Ngắt kết nối')
                  : AppLocale.t('Đăng xuất'),
            ),
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
            label: AppLocale.t('Di chuyển'),
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
            label: AppLocale.t('Nâng hạ'),
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
            label: AppLocale.t('Rẽ hướng'),
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

// ─── Sensor Status Box ──────────────────────────────────────────────────────
// ─── Top Bar ────────────────────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  String? _errorText;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _setError(String message) {
    setState(() => _errorText = message);
  }

  Future<void> _save() async {
    if (_saving) return;
    final oldPwd = _oldCtrl.text;
    final newPwd = _newCtrl.text;
    final confirmPwd = _confirmCtrl.text;

    if (oldPwd.isEmpty || newPwd.isEmpty || confirmPwd.isEmpty) {
      _setError(AppLocale.t('Vui lòng nhập đầy đủ các trường.'));
      return;
    }
    if (newPwd != confirmPwd) {
      _setError(AppLocale.t('Mật khẩu mới không khớp.'));
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final result = await AuthStorage.changePassword(
      oldPassword: oldPwd,
      newPassword: newPwd,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _saving = false;
        _errorText = result.message;
      });
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocale.t('Đổi mật khẩu')),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _oldCtrl,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: AppLocale.t('Mật khẩu cũ')),
              onChanged: (_) => setState(() => _errorText = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCtrl,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: AppLocale.t('Mật khẩu mới')),
              onChanged: (_) => setState(() => _errorText = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: AppLocale.t('Nhập lại mật khẩu mới')),
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
          child: Text(AppLocale.t('Hủy')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocale.t('Lưu')),
        ),
      ],
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
