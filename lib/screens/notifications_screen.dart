import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';

// شاشة النوتفيكيشنز - بتتفتح من جرس الهوم (بدل ما كانت بتودي للداشبورد غلط)
// بتعرض: أونلاين/أوفلاين لأي عداد + تنبيهات الفلو (high/low) + تنبيه التوتال
// كل ده بيتولد تلقائي من الباك اند حسب العتبات اللي اليوزر حددها في Settings
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ApiService.getNotifications();
      setState(() {
        _notifications = result['notifications'] as List<AppNotification>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load notifications';
        _isLoading = false;
      });
    }
  }

  Future<void> _onTapNotification(AppNotification notif) async {
    if (notif.read) return;
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == notif.id);
      if (index != -1) _notifications[index] = notif.copyWith(read: true);
    });
    try {
      await ApiService.markNotificationRead(notif.id);
    } catch (_) {
      // مفيش داعي نزعج المستخدم لو الطلب فشل مؤقتًا، هتتظبط لما يفتح تاني
    }
  }

  Future<void> _markAllRead() async {
    if (_notifications.every((n) => n.read)) return;
    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
    });
    try {
      await ApiService.markAllNotificationsRead();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.read);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(hasUnread),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(bool hasUnread) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 10, 18),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (hasUnread)
                  TextButton(
                    onPressed: _markAllRead,
                    child: const Text('Mark all read',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.offlineRed, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_rounded,
                        color: AppColors.textGrey, size: 44),
                    SizedBox(height: 12),
                    Text('No notifications yet',
                        style: TextStyle(color: AppColors.textGrey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) => _notificationTile(_notifications[index]),
      ),
    );
  }

  Widget _notificationTile(AppNotification notif) {
    final style = _styleFor(notif.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: notif.read ? AppColors.cardWhite : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notif.read ? AppColors.borderGrey : style.color.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () => _onTapNotification(notif),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: style.color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(style.icon, color: style.color, size: 20),
        ),
        title: Text(
          notif.deviceName ?? style.label,
          style: TextStyle(
            fontWeight: notif.read ? FontWeight.w600 : FontWeight.w800,
            color: AppColors.textDark,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            notif.message,
            style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              notif.createdAt != null
                  ? formatTimeAgo(notif.createdAt!.toIso8601String())
                  : '',
              style: TextStyle(color: AppColors.textGrey, fontSize: 11),
            ),
            if (!notif.read) ...[
              const SizedBox(height: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.electricBlue,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _NotifStyle _styleFor(String type) {
    switch (type) {
      case 'device_online':
        return _NotifStyle(Icons.wifi_rounded, AppColors.onlineGreen, 'Device Online');
      case 'device_offline':
        return _NotifStyle(Icons.wifi_off_rounded, AppColors.offlineRed, 'Device Offline');
      case 'flow_high':
        return _NotifStyle(Icons.trending_up_rounded, AppColors.accentOrange, 'Flow High');
      case 'flow_low':
        return _NotifStyle(Icons.trending_down_rounded, AppColors.accentOrange, 'Flow Low');
      case 'total_threshold':
        return _NotifStyle(Icons.water_drop_rounded, AppColors.primaryBlue, 'Total Alert');
      default:
        return _NotifStyle(Icons.notifications_rounded, AppColors.primaryBlue, 'Notification');
    }
  }
}

class _NotifStyle {
  final IconData icon;
  final Color color;
  final String label;
  _NotifStyle(this.icon, this.color, this.label);
}
