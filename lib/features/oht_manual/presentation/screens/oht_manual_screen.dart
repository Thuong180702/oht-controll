import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/oht_ids.dart';
import '../../../../core/enums/connection_phase.dart';
import '../../../../core/enums/event_severity.dart';
import '../../../../core/enums/lidar_zone.dart';
import '../../../../core/theme/app_theme.dart';

import '../../data/services/event_log_excel_exporter.dart';
import '../controllers/oht_manual_controller.dart';
import '../widgets/control_panel_widget.dart';
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

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final esActive = ctrl.emergencyStopActive;
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
          ),
          // ─── Body ───
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Telemetry
                  TelemetryBar(controller: ctrl, onErrorTap: _showLogDialog),
                  const SizedBox(height: 8),
                  // Motor + Sensor row (same height)
                  SizedBox(
                    height: 145,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _MotorStatusBox(controller: ctrl),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: _SensorStatusBox(controller: ctrl),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Speed row
                  SpeedControlRow(controller: ctrl),
                  const SizedBox(height: 8),
                  // 3 Control panels
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: TravelControlBox(controller: ctrl)),
                        const SizedBox(width: 8),
                        Expanded(child: HoistControlBox(controller: ctrl)),
                        const SizedBox(width: 8),
                        Expanded(child: SteerControlBox(controller: ctrl)),
                      ],
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
class _MotorStatusBox extends StatelessWidget {
  const _MotorStatusBox({required this.controller});
  final OhtManualController controller;
  @override
  Widget build(BuildContext context) {
    final motors = controller.telemetry.motors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.memory_rounded,
                size: 13,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                'ĐỘNG CƠ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: MotorIds.all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              mainAxisExtent: 48,
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${m?.speed ?? 0}%  ${m?.direction ?? '-'}',
                      style: const TextStyle(
                        fontSize: 9,
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
  const _SensorStatusBox({required this.controller});
  final OhtManualController controller;
  @override
  Widget build(BuildContext context) {
    final sensors = controller.telemetry.sensors;
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sensors_rounded,
                size: 13,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              const Text(
                'IO / CẢM BIẾN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              mainAxisExtent: 48,
            ),
            itemBuilder: (_, i) => items[i].build(),
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

  Widget build() {
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            txt,
            style: const TextStyle(
              fontSize: 9,
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
  });
  final OhtManualController controller;
  final String username;
  final bool esActive;
  final Future<void> Function() onDisconnect;
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
