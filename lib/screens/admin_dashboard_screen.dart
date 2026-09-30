import 'package:flutter/material.dart';
import '../models/equipment.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/simple_header.dart';

// شاشة لوحة تحكم الأدمن - بتظهر بس في السايدبار لليوزر اللي role بتاعه 'admin'
// (شوفي app_drawer.dart و main_shell.dart). بتدي الأدمن:
// - قائمة كل اليوزرز مع عدد العدادات وعدد الأجهزة المسجل دخولها (Sessions)
// - قفل/تفعيل الاشتراك (الكارت/الخدمة) لكل يوزر بزرار toggle
// - عرض تفاصيل الأجهزة وإنهاء جلسة جهاز معين (فك الارتباط - بيحرر مكانه)
// - إضافة عداد جديد مباشرة ليوزر، أو حذف عداد موجود
class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onMenuTap;

  const AdminDashboardScreen({super.key, required this.onMenuTap});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _error;

  // بنحتفظ بالسيشنز اللي اتحملت لكل يوزر (لما توسعي الكارد بتاعه) عشان منعملش
  // نداء API في كل مرة تقفلي وتفتحي نفس الكارد
  final Map<String, List<Map<String, dynamic>>> _sessionsCache = {};
  final Map<String, List<Equipment>> _metersCache = {};
  final Set<String> _expandedUserIds = {};
  final Set<String> _busyUserIds = {}; // يوزر بيتعمله عملية دلوقتي (toggle/إلخ)

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await ApiService.getAdminUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _toggleExpanded(String userId) async {
    if (_expandedUserIds.contains(userId)) {
      setState(() => _expandedUserIds.remove(userId));
      return;
    }
    setState(() => _expandedUserIds.add(userId));
    if (!_sessionsCache.containsKey(userId)) {
      try {
        final sessions = await ApiService.getUserSessions(userId);
        if (!mounted) return;
        setState(() => _sessionsCache[userId] = sessions);
      } catch (_) {
        if (!mounted) return;
        setState(() => _sessionsCache[userId] = []);
      }
    }
    if (!_metersCache.containsKey(userId)) {
      try {
        final meters = await ApiService.getUserMeters(userId);
        if (!mounted) return;
        setState(() => _metersCache[userId] = meters);
      } catch (_) {
        if (!mounted) return;
        setState(() => _metersCache[userId] = []);
      }
    }
  }

  Future<void> _toggleSubscription(Map<String, dynamic> user) async {
    final userId = user['id'] as String;
    final newValue = !(user['isSubscribed'] as bool? ?? true);
    setState(() => _busyUserIds.add(userId));
    try {
      await ApiService.updateUserSubscription(userId, newValue);
      if (!mounted) return;
      setState(() {
        user['isSubscribed'] = newValue;
        _busyUserIds.remove(userId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyUserIds.remove(userId));
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _terminateSession(
      String userId, Map<String, dynamic> session) async {
    final confirmed = await _confirm(
      title: 'Terminate Session',
      message:
          'End the session for "${session['deviceName'] ?? 'this device'}"? '
          'It will be signed out and free up a device slot.',
    );
    if (confirmed != true) return;

    try {
      await ApiService.terminateSession(userId, session['sessionId']);
      if (!mounted) return;
      setState(() {
        _sessionsCache[userId]
            ?.removeWhere((s) => s['sessionId'] == session['sessionId']);
        final user = _users.firstWhere((u) => u['id'] == userId);
        user['deviceCount'] = (user['deviceCount'] as int? ?? 1) - 1;
      });
      _showSnack('Session terminated');
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _addMeter(Map<String, dynamic> user) async {
    final result = await showDialog<_AddMeterResult>(
      context: context,
      builder: (ctx) => const _AddMeterDialog(),
    );
    if (result == null) return;

    try {
      final device = await ApiService.addMeterForUser(
        userId: user['id'] as String,
        name: result.name,
        type: result.type,
        mqttUnid: result.mqttUnid,
      );
      if (!mounted) return;
      setState(() {
        user['meterCount'] = (user['meterCount'] as int? ?? 0) + 1;
        _metersCache[user['id'] as String]?.add(device);
      });
      _showSnack('Meter added to ${user['username']}');
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _removeMeter(Map<String, dynamic> user, Equipment meter) async {
    final confirmed = await _confirm(
      title: 'Remove Meter',
      message:
          'Remove "${meter.name}" completely from the system? This cannot be undone.',
    );
    if (confirmed != true) return;

    try {
      await ApiService.removeMeter(meter.id);
      if (!mounted) return;
      setState(() {
        _metersCache[user['id'] as String]
            ?.removeWhere((m) => m.id == meter.id);
        user['meterCount'] = (user['meterCount'] as int? ?? 1) - 1;
      });
      _showSnack('Meter removed');
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.offlineRed : Colors.green.shade700,
      ),
    );
  }

  Future<bool?> _confirm({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Confirm',
                style: TextStyle(color: AppColors.offlineRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SimpleHeader(
          title: 'Admin Dashboard',
          subtitle: '${_users.length} accounts',
          icon: Icons.admin_panel_settings_rounded,
          onMenuTap: widget.onMenuTap,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadUsers,
            ),
          ],
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppColors.offlineRed, size: 40),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textGrey)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _users.map(_userCard).toList(),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final userId = user['id'] as String;
    final isSubscribed = user['isSubscribed'] as bool? ?? true;
    final role = user['role'] as String? ?? 'user';
    final deviceCount = user['deviceCount'] as int? ?? 0;
    final maxDevices = user['maxDevices'] as int? ?? 3;
    final meterCount = user['meterCount'] as int? ?? 0;
    final isExpanded = _expandedUserIds.contains(userId);
    final isBusy = _busyUserIds.contains(userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            leading: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: role == 'admin'
                      ? [AppColors.accentOrange, AppColors.accentOrange]
                      : AppColors.headerGradient,
                ),
              ),
              child: Icon(
                role == 'admin' ? Icons.shield_rounded : Icons.person_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(user['name'] ?? user['username'],
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              '@${user['username']} · $meterCount meter(s) · $deviceCount/$maxDevices devices',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
            trailing: isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Switch(
                    value: isSubscribed,
                    activeThumbColor: AppColors.onlineGreen,
                    onChanged: role == 'admin'
                        ? null
                        : (_) => _toggleSubscription(user),
                  ),
            onTap: () => _toggleExpanded(userId),
          ),
          if (!isSubscribed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.lock_rounded,
                      size: 14, color: AppColors.offlineRed),
                  const SizedBox(width: 6),
                  Text('Service locked — subscription inactive',
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.offlineRed)),
                ],
              ),
            ),
          if (isExpanded) _buildExpandedSection(user),
        ],
      ),
    );
  }

  Widget _buildExpandedSection(Map<String, dynamic> user) {
    final userId = user['id'] as String;
    final sessions = _sessionsCache[userId];
    final meters = _metersCache[userId];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.borderGrey, height: 1),
          const SizedBox(height: 12),
          Text('Devices',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGrey)),
          const SizedBox(height: 8),
          if (sessions == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (sessions.isEmpty)
            Text('No devices signed in yet.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textGrey))
          else
            ...sessions.map((s) => _sessionTile(userId, s)),
          const SizedBox(height: 18),
          Text('Meters',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGrey)),
          const SizedBox(height: 8),
          if (meters == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (meters.isEmpty)
            Text('No meters assigned yet.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textGrey))
          else
            ...meters.map((m) => _meterTile(user, m)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addMeter(user),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Add Meter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meterTile(Map<String, dynamic> user, Equipment meter) {
    final typeIcon = switch (meter.type) {
      'relay' => Icons.electrical_services_rounded,
      'valve' => Icons.water_drop_rounded,
      _ => Icons.speed_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(typeIcon, size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meter.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  meter.online ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    color: meter.online
                        ? AppColors.onlineGreen
                        : AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.offlineRed),
            tooltip: 'Remove meter',
            onPressed: () => _removeMeter(user, meter),
          ),
        ],
      ),
    );
  }

  Widget _sessionTile(String userId, Map<String, dynamic> session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_iphone_rounded,
              size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session['deviceName'] ?? 'Unknown device',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (session['lastActiveAt'] != null)
                  Text(
                    'Last active: ${_formatDate(session['lastActiveAt'])}',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textGrey),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded,
                size: 18, color: AppColors.offlineRed),
            tooltip: 'Terminate session',
            onPressed: () => _terminateSession(userId, session),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _AddMeterResult {
  final String name;
  final String type;
  final String? mqttUnid;

  _AddMeterResult({required this.name, required this.type, this.mqttUnid});
}

class _AddMeterDialog extends StatefulWidget {
  const _AddMeterDialog();

  @override
  State<_AddMeterDialog> createState() => _AddMeterDialogState();
}

class _AddMeterDialogState extends State<_AddMeterDialog> {
  final _nameController = TextEditingController();
  final _unidController = TextEditingController();
  String _type = 'sensor';

  @override
  void dispose() {
    _nameController.dispose();
    _unidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Meter'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Device name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'sensor', child: Text('Sensor (meter)')),
              DropdownMenuItem(value: 'relay', child: Text('Relay')),
              DropdownMenuItem(value: 'valve', child: Text('Valve')),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'sensor'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _unidController,
            decoration:
                const InputDecoration(labelText: 'MQTT unid (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(_AddMeterResult(
              name: name,
              type: _type,
              mqttUnid: _unidController.text.trim().isEmpty
                  ? null
                  : _unidController.text.trim(),
            ));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
