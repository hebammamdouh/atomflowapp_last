import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/simple_header.dart';
import 'add_device_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onLogout;

  const SettingsScreen({
    super.key,
    required this.onMenuTap,
    required this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  // عتبات التنبيه (Flow High / Flow Low / Total) - null يعني التنبيه ده لسه مقفول
  Map<String, dynamic> _alertSettings = const {
    'flowHigh': null,
    'flowLow': null,
    'totalThreshold': null,
  };
  bool _isSavingAlerts = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadAlertSettings();
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getMe();
    if (!mounted) return;
    setState(() {
      _user = user;
      _isLoading = false;
    });
  }

  Future<void> _loadAlertSettings() async {
    try {
      final settings = await ApiService.getAlertSettings();
      if (mounted) setState(() => _alertSettings = settings);
    } catch (_) {
      // لو فشل التحميل، هتفضل القيم الافتراضية (كل التنبيهات مقفولة)
    }
  }

  // بتفتح دايالوج فيه حقل رقم واحد لتحديد/تعديل/إلغاء عتبة تنبيه معينة
  Future<void> _editThreshold({
    required String settingsKey,
    required String title,
    required String hint,
    required String unit,
  }) async {
    final current = _alertSettings[settingsKey];
    final controller = TextEditingController(
      text: current != null ? '$current' : '',
    );

    final result = await showDialog<_ThresholdDialogResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: hint, suffixText: unit),
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(const _ThresholdDialogResult.clear()),
              child: Text('Turn off',
                  style: TextStyle(color: AppColors.offlineRed)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null) return;
              Navigator.of(ctx).pop(_ThresholdDialogResult.value(value));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isSavingAlerts = true);
    try {
      Map<String, dynamic> updated;
      if (result.clear) {
        updated = await ApiService.updateAlertSettings(
          clearFlowHigh: settingsKey == 'flowHigh',
          clearFlowLow: settingsKey == 'flowLow',
          clearTotalThreshold: settingsKey == 'totalThreshold',
        );
      } else {
        updated = await ApiService.updateAlertSettings(
          flowHigh: settingsKey == 'flowHigh' ? result.value : null,
          flowLow: settingsKey == 'flowLow' ? result.value : null,
          totalThreshold: settingsKey == 'totalThreshold' ? result.value : null,
        );
      }
      if (mounted) setState(() => _alertSettings = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save alert setting')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingAlerts = false);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onLogout();
            },
            child: Text('Log Out',
                style: TextStyle(color: AppColors.offlineRed)),
          ),
        ],
      ),
    );
  }

  Future<void> _goToAddDevice() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device added successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SimpleHeader(
          title: 'Settings',
          subtitle: 'Account & preferences',
          icon: Icons.tune_rounded,
          onMenuTap: widget.onMenuTap,
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _userCard(),
                    const SizedBox(height: 20),
                    _sectionLabel('Appearance'),
                    _appearanceCard(),
                    const SizedBox(height: 20),
                    _sectionLabel('Devices'),
                    _settingsTile(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Add New Device',
                      subtitle: 'New card with an auto-generated ID',
                      onTap: _goToAddDevice,
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Alerts'),
                    _settingsTile(
                      icon: Icons.trending_up_rounded,
                      label: 'Flow High Alert',
                      subtitle: _alertSettings['flowHigh'] != null
                          ? 'Notify when flow ≥ ${_alertSettings['flowHigh']} m3/h'
                          : 'Off — tap to set a threshold',
                      onTap: _isSavingAlerts
                          ? () {}
                          : () => _editThreshold(
                                settingsKey: 'flowHigh',
                                title: 'Flow High Alert',
                                hint: 'e.g. 50',
                                unit: 'm3/h',
                              ),
                    ),
                    _settingsTile(
                      icon: Icons.trending_down_rounded,
                      label: 'Flow Low Alert',
                      subtitle: _alertSettings['flowLow'] != null
                          ? 'Notify when flow ≤ ${_alertSettings['flowLow']} m3/h'
                          : 'Off — tap to set a threshold',
                      onTap: _isSavingAlerts
                          ? () {}
                          : () => _editThreshold(
                                settingsKey: 'flowLow',
                                title: 'Flow Low Alert',
                                hint: 'e.g. 1',
                                unit: 'm3/h',
                              ),
                    ),
                    _settingsTile(
                      icon: Icons.water_drop_rounded,
                      label: 'Total Alert',
                      subtitle: _alertSettings['totalThreshold'] != null
                          ? 'Notify when total ≥ ${_alertSettings['totalThreshold']} m3'
                          : 'Off — tap to set a threshold',
                      onTap: _isSavingAlerts
                          ? () {}
                          : () => _editThreshold(
                                settingsKey: 'totalThreshold',
                                title: 'Total Alert',
                                hint: 'e.g. 10000',
                                unit: 'm3',
                              ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Account'),
                    _settingsTile(
                      icon: Icons.logout_rounded,
                      label: 'Log Out',
                      iconColor: AppColors.offlineRed,
                      textColor: AppColors.offlineRed,
                      onTap: _confirmLogout,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _userCard() {
    final name = _user?['name'] ?? '--';
    final username = _user?['username'] ?? '--';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: AppColors.headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/robot_face_v2.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text('@$username',
                    style: TextStyle(
                        color: AppColors.textGrey, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _appearanceCard() {
    final themeController = context.watch<ThemeController>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          _themeModeOption(
            icon: Icons.light_mode_rounded,
            label: 'Light',
            selected: themeController.mode == AppThemeMode.light,
            onTap: () => themeController.setMode(AppThemeMode.light),
          ),
          _themeModeOption(
            icon: Icons.dark_mode_rounded,
            label: 'Dark',
            selected: themeController.mode == AppThemeMode.dark,
            onTap: () => themeController.setMode(AppThemeMode.dark),
          ),
          _themeModeOption(
            icon: Icons.settings_suggest_rounded,
            label: 'System',
            selected: themeController.mode == AppThemeMode.system,
            onTap: () => themeController.setMode(AppThemeMode.system),
          ),
        ],
      ),
    );
  }

  Widget _themeModeOption({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryBlue.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primaryBlue : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.primaryBlue : AppColors.textGrey,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primaryBlue : AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textGrey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String label,
    String? subtitle,
    Color? iconColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? AppColors.primaryBlue).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: iconColor ?? AppColors.primaryBlue, size: 20),
        ),
        title: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: textColor ?? AppColors.textDark)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: Icon(Icons.chevron_right_rounded,
            color: AppColors.textGrey),
        onTap: onTap,
      ),
    );
  }
}

// نتيجة دايالوج تعديل عتبة تنبيه - إما رقم جديد اتحدد، أو طلب "إيقاف" التنبيه ده خالص
class _ThresholdDialogResult {
  final double? value;
  final bool clear;

  const _ThresholdDialogResult.value(this.value) : clear = false;
  const _ThresholdDialogResult.clear()
      : value = null,
        clear = true;
}
