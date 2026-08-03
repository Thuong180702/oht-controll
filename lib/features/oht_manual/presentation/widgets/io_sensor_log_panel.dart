import 'package:flutter/material.dart';

import '../../../../core/constants/oht_ids.dart';
import '../../../../core/enums/event_severity.dart';
import '../../../../core/enums/lidar_zone.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/pressable.dart';
import '../../data/services/event_log_excel_exporter.dart';
import '../../domain/entities/alarm_event.dart';
import '../controllers/oht_manual_controller.dart';
import 'motor_display_formatters.dart';

/// Zone 3: Motor status + IO sensors + error log.
/// Must be placed inside an [Expanded] or widget with bounded height.
class IoSensorLogPanel extends StatelessWidget {
  const IoSensorLogPanel({required this.controller, super.key});
  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Motor status section
        _MotorStatusSection(controller: controller),
        const SizedBox(height: 8),
        // Sensor IO section
        _SensorIOSection(controller: controller),
        const SizedBox(height: 8),
        // Error log section — compact, fills rest
        Expanded(child: _ErrorLogSection(controller: controller)),
      ],
    );
  }
}

// ─── Motor Status ─────────────────────────────────────────────────────────────

class _MotorStatusSection extends StatelessWidget {
  const _MotorStatusSection({required this.controller});
  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    final motors = controller.telemetry.motors;
    final sensors = controller.telemetry.sensors;
    return _CardBox(
      title: 'ĐỘNG CƠ',
      icon: Icons.memory_rounded,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: MotorIds.all.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          mainAxisExtent: 56,
        ),
        itemBuilder: (context, i) {
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  formatMotorDetails(id, m, sensors),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Sensor IO ────────────────────────────────────────────────────────────────

class _SensorIOSection extends StatelessWidget {
  const _SensorIOSection({required this.controller});
  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    final sensors = controller.telemetry.sensors;

    // Build sensor items in a 2-column grid for neat layout
    final boolEntries = SensorIds.boolSensorLabels.entries.toList();

    return _CardBox(
      title: 'IO / CẢM BIẾN',
      icon: Icons.sensors_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bool sensors in 2-column grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: boolEntries.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              mainAxisExtent: 32,
            ),
            itemBuilder: (context, i) {
              final e = boolEntries[i];
              final value = sensors.boolValue(e.key);
              final isLimit =
                  e.key == SensorIds.hoistFrontUpperLimit ||
                  e.key == SensorIds.hoistRearUpperLimit ||
                  e.key == SensorIds.steerFrontLeft ||
                  e.key == SensorIds.steerFrontRight ||
                  e.key == SensorIds.steerRearLeft ||
                  e.key == SensorIds.steerRearRight;

              final Color color;
              final String txt;
              if (value == null) {
                color = AppColors.textHint;
                txt = '—';
              } else if (value && isLimit) {
                color = AppColors.warning;
                txt = 'ON';
              } else if (value) {
                color = AppColors.success;
                txt = 'ON';
              } else {
                color = AppColors.textHint;
                txt = 'OFF';
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      txt,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // Lidar bars in a row
          Row(
            children: [
              for (final e in SensorIds.lidarSensorLabels.entries)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _LidarBar(
                      label: e.value,
                      zone: sensors.lidarValue(e.key),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LidarBar extends StatelessWidget {
  const _LidarBar({required this.label, required this.zone});
  final String label;
  final LidarZone zone;

  Color get _color => switch (zone) {
    LidarZone.clear => AppColors.success,
    LidarZone.warning => AppColors.warning,
    LidarZone.danger => AppColors.error,
    LidarZone.noData => AppColors.textHint,
  };

  String get _txt => switch (zone) {
    LidarZone.clear => 'Thông thoáng',
    LidarZone.warning => 'Cảnh báo',
    LidarZone.danger => 'Nguy hiểm',
    LidarZone.noData => 'Không có dữ liệu',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.radar_rounded, size: 13, color: _color),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  _txt,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error Log ────────────────────────────────────────────────────────────────

class _ErrorLogSection extends StatefulWidget {
  const _ErrorLogSection({required this.controller});
  final OhtManualController controller;

  @override
  State<_ErrorLogSection> createState() => _ErrorLogSectionState();
}

class _ErrorLogSectionState extends State<_ErrorLogSection> {
  void _showFullLog() {
    showDialog<void>(
      context: context,
      builder: (_) => _FullLogDialog(controller: widget.controller),
    );
  }

  Future<void> _downloadLog() async {
    await _downloadEventsAsExcel(context, widget.controller);
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.controller.events;
    final latest = events.isNotEmpty ? events.first : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 0),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 12,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  'LOG SỰ KIỆN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (events.isNotEmpty)
                  Text(
                    '${events.length}',
                    style: TextStyle(fontSize: 10, color: AppColors.textHint),
                  ),
                const SizedBox(width: 4),
                _ActionBtn(
                  icon: Icons.open_in_full_rounded,
                  tip: 'Xem toàn bộ',
                  onTap: _showFullLog,
                ),
                _ActionBtn(
                  icon: Icons.download_rounded,
                  tip: 'Tải xuống',
                  onTap: _downloadLog,
                ),
                _ActionBtn(
                  icon: Icons.delete_outline_rounded,
                  tip: 'Xóa log',
                  onTap: widget.controller.clearEvents,
                  color: AppColors.error,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Divider(height: 1),
          // Latest entry banner (compact)
          if (latest != null)
            Pressable(
              onTap: _showFullLog,
              pressedScale: 0.99,
              pressedOpacity: 0.78,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _sevBg(latest.severity),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _sevColor(latest.severity).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _sevIcon(latest.severity),
                      size: 13,
                      color: _sevColor(latest.severity),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        latest.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _sevColor(latest.severity),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 12,
                      color: AppColors.textHint,
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 12,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Không có log lỗi',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          // Mini log list
          Expanded(
            child: events.length > 1
                ? ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: events.length > 5 ? 5 : events.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, i) => _LogRow(event: events[i]),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.event});
  final AlarmEvent event;

  @override
  Widget build(BuildContext context) {
    final color = _sevColor(event.severity);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            formatClock(event.timestamp),
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textHint,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              event.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Full Log Dialog ──────────────────────────────────────────────────────────

class _FullLogDialog extends StatelessWidget {
  const _FullLogDialog({required this.controller});
  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    final events = controller.events;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 660,
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Toàn bộ log lỗi / sự kiện',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${events.length} mục',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        'Không có sự kiện',
                        style: TextStyle(color: AppColors.textHint),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: events.length,
                      separatorBuilder: (context, index) => Divider(height: 1),
                      itemBuilder: (context, i) => _FullRow(event: events[i]),
                    ),
            ),
            // Actions
            Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _downloadEventsAsExcel(context, controller),
                    icon: Icon(Icons.download_rounded, size: 14),
                    label: Text('Tải xuống Excel'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      textStyle: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: controller.clearEvents,
                    icon: Icon(Icons.delete_outline_rounded, size: 14),
                    label: Text('Xóa log'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 34),
                      textStyle: TextStyle(fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      textStyle: TextStyle(fontSize: 12),
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

class _FullRow extends StatelessWidget {
  const _FullRow({required this.event});
  final AlarmEvent event;

  @override
  Widget build(BuildContext context) {
    final color = _sevColor(event.severity);
    final t = event.timestamp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}:'
            '${t.second.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textHint,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              event.severity.name.toUpperCase(),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.message,
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
  }
}

// ─── Shared Card Box ──────────────────────────────────────────────────────────

class _CardBox extends StatelessWidget {
  const _CardBox({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.tip,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.86,
        pressedOpacity: 0.72,
        semanticLabel: tip,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: color ?? AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ─── Severity helpers ─────────────────────────────────────────────────────────

Future<void> _downloadEventsAsExcel(
  BuildContext context,
  OhtManualController controller,
) async {
  try {
    final result = await EventLogExcelExporter.export(controller.events);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã tải log Excel: $result')));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Không thể tải log Excel: $error')));
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

Color _sevBg(EventSeverity s) => switch (s) {
  EventSeverity.info => AppColors.infoBg,
  EventSeverity.warning => AppColors.warningBg,
  EventSeverity.critical => AppColors.errorBg,
  EventSeverity.command => AppColors.primarySurface,
  EventSeverity.ack => AppColors.successBg,
  EventSeverity.nack => AppColors.errorBg,
};

IconData _sevIcon(EventSeverity s) => switch (s) {
  EventSeverity.info => Icons.info_outline_rounded,
  EventSeverity.warning => Icons.warning_amber_rounded,
  EventSeverity.critical => Icons.error_outline_rounded,
  EventSeverity.command => Icons.send_rounded,
  EventSeverity.ack => Icons.check_circle_outline_rounded,
  EventSeverity.nack => Icons.cancel_outlined,
};
