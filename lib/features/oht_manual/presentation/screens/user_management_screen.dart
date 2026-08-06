import 'package:flutter/material.dart';

import '../../../../core/models/user_account.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_locale.dart';
import '../../../../core/utils/auth_storage.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({
    required this.currentUsername,
    required this.onBack,
    super.key,
  });

  final String currentUsername;
  final VoidCallback onBack;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<UserAccount> _accounts = [];
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    await AuthStorage.ensureSeeded();
    if (!mounted) return;
    setState(() {
      _accounts = AuthStorage.getAccounts();
      _loading = false;
    });
  }

  List<UserAccount> get _filteredAccounts {
    if (_searchQuery.trim().isEmpty) return _accounts;
    final query = _searchQuery.trim().toLowerCase();
    return _accounts.where((a) => a.username.toLowerCase().contains(query)).toList();
  }

  Future<void> _openAccountDialog({UserAccount? account}) async {
    final isEditing = account != null;
    final usernameCtrl = TextEditingController(text: account?.username ?? '');
    final passwordCtrl = TextEditingController(text: account?.password ?? '');
    int selectedRole = account?.role ?? 1;
    bool isLocked = account?.isLocked ?? false;
    bool obscurePassword = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.manage_accounts : Icons.person_add_alt_1,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? AppLocale.t('Chỉnh sửa tài khoản') : AppLocale.t('Thêm tài khoản mới'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username Field
                      Text(AppLocale.t('Tên đăng nhập'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: usernameCtrl,
                        enabled: !isEditing,
                        decoration: InputDecoration(
                          hintText: AppLocale.t('Nhập tên tài khoản...'),
                          prefixIcon: const Icon(Icons.person, size: 20),
                          filled: true,
                          fillColor: isEditing ? AppColors.surfaceVariant.withValues(alpha: 0.5) : AppColors.surfaceVariant,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      Text(AppLocale.t('Mật khẩu'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          hintText: AppLocale.t('Nhập mật khẩu...'),
                          prefixIcon: const Icon(Icons.lock, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setModalState(() => obscurePassword = !obscurePassword),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Role Dropdown (0: Admin, 1: Control, 2: Viewer)
                      Text(AppLocale.t('Phân quyền truy cập'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedRole,
                            isExpanded: true,
                            dropdownColor: AppColors.surface,
                            items: [
                              DropdownMenuItem(
                                value: 0,
                                child: Row(
                                  children: [
                                    const Icon(Icons.admin_panel_settings, color: Colors.purpleAccent, size: 20),
                                    const SizedBox(width: 10),
                                    Text(AppLocale.t('0 - Admin (Quản trị toàn hệ thống)')),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 1,
                                child: Row(
                                  children: [
                                    const Icon(Icons.sports_esports, color: Colors.greenAccent, size: 20),
                                    const SizedBox(width: 10),
                                    Text(AppLocale.t('1 - Điều khiển (Operator - Thao tác & Giám sát)')),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 2,
                                child: Row(
                                  children: [
                                    const Icon(Icons.visibility, color: Colors.amberAccent, size: 20),
                                    const SizedBox(width: 10),
                                    Text(AppLocale.t('2 - Chỉ giám sát (Viewer - Xem dữ liệu)')),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedRole = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Lock Status Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppLocale.t('Trạng thái tài khoản'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                              Text(
                                isLocked ? AppLocale.t('Đang bị khóa (Không thể đăng nhập)') : AppLocale.t('Đang hoạt động'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isLocked ? AppColors.error : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: !isLocked,
                            activeThumbColor: AppColors.success,
                            onChanged: (active) {
                              setModalState(() => isLocked = !active);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text(AppLocale.t('Hủy')),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(isEditing ? AppLocale.t('Lưu thay đổi') : AppLocale.t('Tạo tài khoản')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final u = usernameCtrl.text.trim();
                    final p = passwordCtrl.text.trim();

                    if (u.isEmpty || p.isEmpty) {
                      if (dialogCtx.mounted) {
                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                          SnackBar(content: Text(AppLocale.t('Tên đăng nhập và mật khẩu không được trống.'))),
                        );
                      }
                      return;
                    }

                    final newAcc = UserAccount(
                      username: u,
                      password: p,
                      role: selectedRole,
                      isLocked: isLocked,
                      createdAt: account?.createdAt ?? DateTime.now().toIso8601String(),
                    );

                    final res = await AuthStorage.saveAccount(newAcc);
                    if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();

                    await _loadAccounts();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocale.t(res.message))),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleLock(UserAccount account) async {
    final res = await AuthStorage.toggleLockAccount(account.username);
    await _loadAccounts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.t(res.message))),
      );
    }
  }

  Future<void> _confirmDelete(UserAccount account) async {
    if (account.username.toLowerCase() == 'thaco') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.t('Không thể xóa tài khoản Thaco (Admin mặc định).'))),
      );
      return;
    }

    if (account.username.toLowerCase() == widget.currentUsername.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.t('Không thể xóa tài khoản Admin bạn đang sử dụng.'))),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppLocale.t('Xác nhận xóa tài khoản')),
        content: Text(AppLocale.t('Bạn có chắc chắn muốn xóa tài khoản "${account.username}"? Hành động này không thể hoàn tác.')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(AppLocale.t('Hủy'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocale.t('Xóa'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await AuthStorage.deleteAccount(account.username);
      await _loadAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocale.t(res.message))),
        );
      }
    }
  }

  Widget _buildRoleBadge(int role) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (role) {
      case 0:
        bg = Colors.purple.withValues(alpha: 0.2);
        fg = Colors.purpleAccent;
        label = '0 - Admin';
        icon = Icons.admin_panel_settings;
        break;
      case 1:
        bg = Colors.green.withValues(alpha: 0.2);
        fg = Colors.greenAccent;
        label = '1 - Điều khiển';
        icon = Icons.sports_esports;
        break;
      case 2:
      default:
        bg = Colors.amber.withValues(alpha: 0.2);
        fg = Colors.amberAccent;
        label = '2 - Chỉ giám sát';
        icon = Icons.visibility;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            AppLocale.t(label),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isLocked) {
    final bg = isLocked ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2);
    final fg = isLocked ? AppColors.error : AppColors.success;
    final label = isLocked ? 'Đã khóa' : 'Hoạt động';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isLocked ? Icons.lock : Icons.check_circle, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            AppLocale.t(label),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAccounts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Row(
          children: [
            Icon(Icons.manage_accounts, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              AppLocale.t('Quản lý tài khoản (Admin Console)'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person_add, size: 18),
              label: Text(AppLocale.t('Thêm tài khoản')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _openAccountDialog(),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Search & Quick Stats Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: AppLocale.t('Tìm kiếm tài khoản theo tên...'),
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.surfaceBorder),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Text(
                          '${AppLocale.t("Tổng số tài khoản")}: ${_accounts.length}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Accounts Table View
                  Expanded(
                    child: Card(
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.surfaceBorder),
                      ),
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                AppLocale.t('Không tìm thấy tài khoản nào.'),
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.surfaceBorder),
                              itemBuilder: (context, index) {
                                final acc = filtered[index];
                                final isCurrent = acc.username.toLowerCase() == widget.currentUsername.toLowerCase();

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: acc.isAdmin
                                        ? Colors.purple.withValues(alpha: 0.3)
                                        : acc.isOperator
                                            ? Colors.green.withValues(alpha: 0.3)
                                            : Colors.amber.withValues(alpha: 0.3),
                                    child: Icon(
                                      acc.isAdmin
                                          ? Icons.admin_panel_settings
                                          : acc.isOperator
                                              ? Icons.sports_esports
                                              : Icons.visibility,
                                      color: acc.isAdmin
                                          ? Colors.purpleAccent
                                          : acc.isOperator
                                              ? Colors.greenAccent
                                              : Colors.amberAccent,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        acc.username,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            AppLocale.t('Bạn'),
                                            style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Mật khẩu: ${'•' * acc.password.length}',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildRoleBadge(acc.role),
                                      const SizedBox(width: 12),
                                      _buildStatusBadge(acc.isLocked),
                                      const SizedBox(width: 16),

                                      // Edit Account Button
                                      IconButton(
                                        tooltip: AppLocale.t('Chỉnh sửa'),
                                        icon: Icon(Icons.edit, color: AppColors.primary),
                                        onPressed: () => _openAccountDialog(account: acc),
                                      ),

                                      // Lock / Unlock Button
                                      IconButton(
                                        tooltip: acc.isLocked ? AppLocale.t('Mở khóa') : AppLocale.t('Khóa tài khoản'),
                                        icon: Icon(
                                          acc.isLocked ? Icons.lock_open : Icons.lock,
                                          color: acc.isLocked ? AppColors.success : AppColors.warning,
                                        ),
                                        onPressed: () => _toggleLock(acc),
                                      ),

                                      // Delete Button
                                      IconButton(
                                        tooltip: AppLocale.t('Xóa tài khoản'),
                                        icon: Icon(Icons.delete_forever, color: AppColors.error),
                                        onPressed: () => _confirmDelete(acc),
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
            ),
    );
  }
}
