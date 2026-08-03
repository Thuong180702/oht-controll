import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/enums/manual_command_type.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../controllers/oht_manual_controller.dart';
import 'motor_display_formatters.dart';

// ─── Speed Row ───────────────────────────────────────────────────────────────
class SpeedControlRow extends StatelessWidget {
  const SpeedControlRow({required this.controller, super.key});
  final OhtManualController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.speed_rounded, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'TỐC ĐỘ',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          _SpeedSlider(
            label: 'Di chuyển',
            value: controller.travelSpeed,
            onChanged: controller.setTravelSpeed,
          ),
          const SizedBox(width: 16),
          _SpeedSlider(
            label: 'Nâng hạ',
            value: controller.hoistSpeed,
            onChanged: controller.setHoistSpeed,
          ),
          const SizedBox(width: 16),
          _SpeedSlider(
            label: 'Rẻ hướng',
            value: controller.steerSpeed,
            onChanged: controller.setSteerSpeed,
          ),
          const Spacer(),
          _ModePill(controller: controller),
        ],
      ),
    );
  }
}

class _SpeedSlider extends StatelessWidget {
  const _SpeedSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        _SmallBtn(
          icon: Icons.remove_rounded,
          onTap: value > 0 ? () => onChanged((value - 1).toDouble()) : null,
        ),
        const SizedBox(width: 4),
        Container(
          width: 72,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            formatCommandSpeedMps(value),
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _SmallBtn(
          icon: Icons.add_rounded,
          onTap: value < 100 ? () => onChanged((value + 1).toDouble()) : null,
        ),
      ],
    );
  }
}

class _SmallBtn extends StatefulWidget {
  const _SmallBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_SmallBtn> createState() => _SmallBtnState();
}

class _SmallBtnState extends State<_SmallBtn> {
  Timer? _timer;

  void _startTimer() {
    if (widget.onTap == null) return;
    widget.onTap!();
    _timer = Timer(const Duration(milliseconds: 400), () {
      _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (widget.onTap != null) widget.onTap!();
      });
    });
  }

  void _stopTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void didUpdateWidget(covariant _SmallBtn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null) {
      _stopTimer();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Pressable(
      enabled: enabled,
      onPressStart: _startTimer,
      onPressEnd: _stopTimer,
      pressedScale: 0.90,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primarySurface : AppColors.surfaceBorder,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          widget.icon,
          size: 14,
          color: enabled ? AppColors.primary : AppColors.textHint,
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.controller});
  final OhtManualController controller;
  @override
  Widget build(BuildContext context) {
    final ok = controller.manualControlsEnabled;
    final c = ok ? AppColors.primary : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.block_rounded,
            size: 12,
            color: c,
          ),
          const SizedBox(width: 4),
          Text(
            ok ? 'Khả dụng' : 'Bị khóa',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Group Box ───────────────────────────────────────────────────────────────
class _GroupBox extends StatelessWidget {
  const _GroupBox({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: c),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: c,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─── Pretty Command Button ──────────────────────────────────────────────────
class CmdBtn extends StatelessWidget {
  const CmdBtn({
    required this.label,
    required this.icon,
    required this.type,
    required this.controller,
    this.width,
    this.height = 48,
    this.isStop = false,
    this.isPrimary = false,
    super.key,
  });
  final String label;
  final IconData icon;
  final ManualCommandType type;
  final OhtManualController controller;
  final double? width;
  final double height;
  final bool isStop;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final reason = controller.blockReasonFor(type);
    final enabled = reason == null;
    final (Color bg, Color fg, Color bd) = !enabled
        ? (AppColors.surfaceBorder, AppColors.textHint, AppColors.surfaceBorder)
        : isStop
        ? (
            const Color(0xFFFFF7ED),
            AppColors.warning,
            AppColors.warning.withValues(alpha: 0.5),
          )
        : isPrimary
        ? (AppColors.primary, Colors.white, AppColors.primary)
        : (
            AppColors.primarySurface,
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.3),
          );

    return Tooltip(
      message: reason ?? label,
      child: Pressable(
        enabled: enabled,
        onPressStart: enabled && !isStop
            ? () => controller.sendManualCommand(type)
            : null,
        onPressEnd: enabled && !isStop
            ? () => controller.sendManualCommand(_stopTypeFor(type))
            : null,
        onTap: enabled && isStop
            ? () => controller.sendManualCommand(type)
            : null,
        pressedScale: 0.97,
        pressedOpacity: 0.76,
        semanticLabel: label,
        child: AnimatedContainer(
          alignment: Alignment.center,
          duration: const Duration(milliseconds: 150),
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: enabled && !isStop
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [bg, bg.withValues(alpha: 0.85)],
                  )
                : null,
            color: enabled && !isStop ? null : bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bd, width: isStop ? 1.5 : 1),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: fg.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ManualCommandType _stopTypeFor(ManualCommandType t) {
    if (t.name.startsWith('travel')) return ManualCommandType.travelStop;
    if (t.name.startsWith('steer')) return ManualCommandType.steerStop;
    if (t.name.startsWith('hoist')) return ManualCommandType.hoistStop;
    return t; // fallback
  }
}

// ─── Unified Button (callback-based, checks block reason) ───────────────────
class _UnifiedBtn extends StatelessWidget {
  const _UnifiedBtn({
    required this.label,
    required this.icon,
    required this.onTapDown,
    required this.onTapUp,
    this.blockReason,
    this.width,
    this.height = 48,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final String? blockReason;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = blockReason == null && onTapDown != null;
    final Color bg = enabled
        ? AppColors.primarySurface
        : AppColors.surfaceBorder;
    final Color fg = enabled ? AppColors.primary : AppColors.textHint;
    final Color bd = enabled
        ? AppColors.primary.withValues(alpha: 0.3)
        : AppColors.surfaceBorder;
    return Tooltip(
      message: blockReason ?? label,
      child: Pressable(
        enabled: enabled,
        onPressStart: enabled ? onTapDown : null,
        onPressEnd: enabled ? onTapUp : null,
        pressedScale: 0.97,
        pressedOpacity: 0.76,
        semanticLabel: label,
        child: AnimatedContainer(
          alignment: Alignment.center,
          duration: const Duration(milliseconds: 150),
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [bg, bg.withValues(alpha: 0.85)],
                  )
                : null,
            color: enabled ? null : bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bd),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: fg.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Travel Control ─────────────────────────────────────────────────────────
class TravelControlBox extends StatelessWidget {
  const TravelControlBox({required this.controller, super.key});
  final OhtManualController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _GroupBox(
      title: 'DI CHUYỂN',
      icon: Icons.navigation_rounded,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CmdBtn(
                    label: 'Tiến',
                    icon: Icons.arrow_upward_rounded,
                    type: ManualCommandType.travelForward,
                    controller: c,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: CmdBtn(
                    label: 'Lùi',
                    icon: Icons.arrow_downward_rounded,
                    type: ManualCommandType.travelBackward,
                    controller: c,
                    width: double.infinity,
                    height: double.infinity,
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

// ─── Steer Control ──────────────────────────────────────────────────────────
class SteerControlBox extends StatelessWidget {
  const SteerControlBox({required this.controller, super.key});
  final OhtManualController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _GroupBox(
      title: 'RẺ HƯỚNG',
      icon: Icons.turn_right_rounded,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _UnifiedBtn(
              label: 'Trái',
              icon: Icons.turn_left_rounded,
              blockReason: c.blockReasonForUnifiedSteer(left: true),
              onTapDown: () => c.sendUnifiedSteer(left: true),
              onTapUp: () => c.sendManualCommand(ManualCommandType.steerStop),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _UnifiedBtn(
              label: 'Phải',
              icon: Icons.turn_right_rounded,
              blockReason: c.blockReasonForUnifiedSteer(left: false),
              onTapDown: () => c.sendUnifiedSteer(left: false),
              onTapUp: () => c.sendManualCommand(ManualCommandType.steerStop),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hoist Control ──────────────────────────────────────────────────────────
class HoistControlBox extends StatelessWidget {
  const HoistControlBox({required this.controller, super.key});
  final OhtManualController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return _GroupBox(
      title: 'NÂNG HẠ',
      icon: Icons.open_in_full_rounded,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _UnifiedBtn(
                    label: 'Nâng',
                    icon: Icons.vertical_align_top_rounded,
                    blockReason: c.blockReasonForUnifiedHoist(up: true),
                    onTapDown: () => c.sendUnifiedHoist(up: true),
                    onTapUp: () =>
                        c.sendManualCommand(ManualCommandType.hoistStop),
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: _UnifiedBtn(
                    label: 'Hạ',
                    icon: Icons.vertical_align_bottom_rounded,
                    blockReason: c.blockReasonForUnifiedHoist(up: false),
                    onTapDown: () => c.sendUnifiedHoist(up: false),
                    onTapUp: () =>
                        c.sendManualCommand(ManualCommandType.hoistStop),
                    width: double.infinity,
                    height: double.infinity,
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

// ─── System Bar ─────────────────────────────────────────────────────────────
class SystemControlBar extends StatelessWidget {
  const SystemControlBar({required this.controller, super.key});
  final OhtManualController controller;
  @override
  Widget build(BuildContext context) {
    final active = controller.emergencyStopActive;
    final connected = controller.isConnected;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.settings_rounded, size: 13, color: AppColors.error),
          const SizedBox(width: 6),
          Text(
            'HỆ THỐNG',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.error,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 14),
          CmdBtn(
            label: 'Chế độ\nThủ công',
            icon: Icons.pan_tool_alt_rounded,
            type: ManualCommandType.setManualMode,
            controller: controller,
            width: 110,
            height: 48,
            isPrimary: true,
          ),
          const SizedBox(width: 8),
          CmdBtn(
            label: 'Reset lỗi',
            icon: Icons.restart_alt_rounded,
            type: ManualCommandType.resetError,
            controller: controller,
            width: 95,
            height: 48,
          ),
          const SizedBox(width: 14),
          // E-Stop fills remaining
          Expanded(
            child: Pressable(
              enabled: connected,
              onTap: connected
                  ? () => controller.sendManualCommand(
                      ManualCommandType.emergencyStop,
                    )
                  : null,
              pressedScale: 0.985,
              pressedOpacity: 0.72,
              semanticLabel: 'Emergency stop',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                decoration: BoxDecoration(
                  color: connected
                      ? (active ? AppColors.emergency : const Color(0xFFDC2626))
                      : const Color(0xFFBFCAD6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: connected
                        ? (active
                              ? const Color(0xFF7F1D1D)
                              : const Color(0xFFB91C1C))
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: connected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFDC2626,
                            ).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.report_rounded,
                      color: connected ? Colors.white : Colors.white54,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DỪNG KHẨN CẤP',
                      style: TextStyle(
                        color: connected ? Colors.white : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
