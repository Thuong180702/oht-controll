import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_locale.dart';
import '../../../../core/widgets/pressable.dart';

enum IndustrialTopBarItem { dashboard, diagnostics, connection, logs, settings }

extension IndustrialTopBarItemMeta on IndustrialTopBarItem {
  String labelFor(String languageCode) {
    final english = languageCode == 'en';
    return switch (this) {
      IndustrialTopBarItem.dashboard =>
        english ? 'DASHBOARD' : 'BẢNG ĐIỀU KHIỂN',
      IndustrialTopBarItem.diagnostics => english ? 'DIAGNOSTICS' : 'CHẨN ĐOÁN',
      IndustrialTopBarItem.connection => english ? 'CONNECTION' : 'KẾT NỐI',
      IndustrialTopBarItem.logs => english ? 'LOGS' : 'NHẬT KÝ',
      IndustrialTopBarItem.settings => english ? 'SETTINGS' : 'CÀI ĐẶT',
    };
  }

  IconData get icon => switch (this) {
    IndustrialTopBarItem.dashboard => Icons.monitor_heart_outlined,
    IndustrialTopBarItem.diagnostics => Icons.analytics_outlined,
    IndustrialTopBarItem.connection => Icons.cable_outlined,
    IndustrialTopBarItem.logs => Icons.receipt_long_outlined,
    IndustrialTopBarItem.settings => Icons.tune_outlined,
  };
}

class IndustrialTopBar extends StatelessWidget {
  const IndustrialTopBar({
    required this.activeItem,
    this.username,
    this.statusLabel,
    this.statusColor,
    this.languageCode = 'vi',
    this.emergencyActive = false,
    this.onEmergencyPressed,
    this.onItemSelected,
    this.onUserTap,
    this.onExit,
    this.exitLabel,
    this.exitIcon = Icons.logout_rounded,
    this.updateAvailable = false,
    this.onUpdateTap,
    super.key,
  });

  final IndustrialTopBarItem activeItem;
  final String? username;
  final String? statusLabel;
  final Color? statusColor;
  final String languageCode;
  final bool emergencyActive;
  final bool updateAvailable;
  final VoidCallback? onUpdateTap;
  final VoidCallback? onEmergencyPressed;
  final ValueChanged<IndustrialTopBarItem>? onItemSelected;
  final VoidCallback? onUserTap;
  final VoidCallback? onExit;
  final String? exitLabel;
  final IconData exitIcon;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 850;
    final showContextDetails = width >= 1100;

    return Container(
      key: const Key('industrial_top_bar'),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          _BrandMark(compact: isCompact),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TopNav(
                  activeItem: activeItem,
                  languageCode: languageCode,
                  compact: isCompact,
                  onItemSelected: onItemSelected,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (showContextDetails && statusLabel != null) ...[
            _StatusPill(
              label: statusLabel!,
              color: statusColor ?? AppColors.textHint,
            ),
            const SizedBox(width: 6),
          ],
          if (showContextDetails && username != null) ...[
            _UserChip(username: username!, onTap: onUserTap),
            const SizedBox(width: 6),
          ],
          if (onExit != null && exitLabel != null) ...[
            _ExitButton(
              label: exitLabel!,
              icon: exitIcon,
              compact: isCompact,
              onTap: onExit!,
            ),
            const SizedBox(width: 6),
          ],
          if (updateAvailable) ...[
            _UpdateChip(onTap: onUpdateTap),
            const SizedBox(width: 6),
          ],
          _EmergencyButton(
            key: Key('emergency_stop_button_${activeItem.name}'),
            active: emergencyActive,
            compact: isCompact,
            onTap: onEmergencyPressed,
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: 'OHT CONTROL SYSTEM',
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.precision_manufacturing_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      );
    }

    return SizedBox(
      key: const Key('top_bar_brand'),
      width: 195,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.precision_manufacturing_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OHT CONTROL SYSTEM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'MANUAL CONTROL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
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

class _TopNav extends StatelessWidget {
  const _TopNav({
    required this.activeItem,
    required this.languageCode,
    required this.compact,
    this.onItemSelected,
  });

  final IndustrialTopBarItem activeItem;
  final String languageCode;
  final bool compact;
  final ValueChanged<IndustrialTopBarItem>? onItemSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: IndustrialTopBarItem.values
          .map(
            (item) => _TopNavItem(
              item: item,
              languageCode: languageCode,
              active: item == activeItem,
              compact: compact,
              onTap: onItemSelected == null
                  ? null
                  : () => onItemSelected!(item),
            ),
          )
          .toList(),
    );
  }
}

class _TopNavItem extends StatelessWidget {
  const _TopNavItem({
    required this.item,
    required this.languageCode,
    required this.active,
    required this.compact,
    this.onTap,
  });

  final IndustrialTopBarItem item;
  final String languageCode;
  final bool active;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textSecondary;
    final label = item.labelFor(languageCode);

    final itemContent = Container(
      key: active ? Key('top_nav_${item.name}_active') : null,
      height: 52,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 10),
      decoration: BoxDecoration(
        color: active ? AppColors.primarySurfaceLight : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: active ? AppColors.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: compact
          ? Center(child: Icon(item.icon, size: 20, color: color))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
    );

    return Tooltip(
      message: label,
      child: InkWell(
        key: Key('top_nav_${item.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: itemContent,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({required this.username, this.onTap});

  final String username;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              username,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExitButton extends StatelessWidget {
  const _ExitButton({
    required this.label,
    required this.icon,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Icon(icon, size: 16, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton({
    super.key,
    required this.active,
    required this.compact,
    this.onTap,
  });

  final bool active;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.emergency : AppColors.error;

    if (compact) {
      return Tooltip(
        message: AppLocale.t('Dừng khẩn cấp'),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.emergency, width: 1),
            ),
            child: const Icon(
              Icons.report_problem_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: AppLocale.t('Dừng khẩn cấp'),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.emergency, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.report_problem_outlined,
                color: Colors.white,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                AppLocale.t('DỪNG KHẨN CẤP'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
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

class _UpdateChip extends StatelessWidget {
  const _UpdateChip({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.system_update_rounded, size: 13, color: AppColors.warning),
            const SizedBox(width: 4),
            Text(
              'UPDATE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.warning,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
