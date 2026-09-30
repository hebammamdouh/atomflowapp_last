import 'dart:async';
import 'package:flutter/material.dart';
import '../models/equipment.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/equipment_card.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onMenuTap;
  final String userName;
  final VoidCallback? onOpenDashboard;

  const HomeScreen({
    super.key,
    required this.onMenuTap,
    this.userName = 'User',
    this.onOpenDashboard,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _DeviceFilter { all, online, offline, favorite }

class _HomeScreenState extends State<HomeScreen> {
  List<Equipment> _devices = [];
  bool _isLoading = true;
  String? _error;
  _DeviceFilter _filter = _DeviceFilter.all;
  int _unreadNotifications = 0;

  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadEquipment();
    _refreshUnreadCount();
    // بنحدّث التاريخ/الوقت المعروضين فوق الصفحة كل دقيقة
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // بولينج صامت كل 4 ثواني عشان القرايات تتحدث لايف من غير ما المستخدم يعمل Pull-to-Refresh
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _silentRefresh();
      _refreshUnreadCount();
    });
  }

  // بيجيب عدد النوتفيكيشنز الغير مقروءة عشان يظهرها كنقطة حمراء فوق جرس التنبيهات
  Future<void> _refreshUnreadCount() async {
    if (!mounted) return;
    try {
      final result = await ApiService.getNotifications(limit: 1);
      if (mounted) {
        setState(() => _unreadNotifications = result['unreadCount'] as int? ?? 0);
      }
    } catch (_) {
      // فشل صامت - مش لازم يزعج المستخدم
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _refreshUnreadCount();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // تحديث في الخلفية من غير سبينر أو فلاش - بيحدث القرايات والحالة أونلاين/أوفلاين لايف
  Future<void> _silentRefresh() async {
    if (!mounted || _isLoading) return;
    try {
      final devices = await ApiService.getEquipment();
      if (mounted) setState(() => _devices = devices);
    } catch (_) {
      // فشل التحديث الصامت مش لازم يقاطع المستخدم بأي error banner
    }
  }

  Future<void> _loadEquipment() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final devices = await ApiService.getEquipment();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // بيتنادى من أي كارت لما يتحدث محليًا (فيفورت/تحكم/اسم/لوكيشن) عشان
  // الليستة الأصلية تتزامن فورًا - وده اللي بيخلي فلتر Favorite في الهوم شغال صح
  void _onDeviceUpdated(Equipment updated) {
    final index = _devices.indexWhere((d) => d.id == updated.id);
    if (index == -1) return;
    setState(() => _devices[index] = updated);
  }

  List<Equipment> get _filteredDevices {
    switch (_filter) {
      case _DeviceFilter.online:
        return _devices.where((d) => d.online).toList();
      case _DeviceFilter.offline:
        return _devices.where((d) => !d.online).toList();
      case _DeviceFilter.favorite:
        return _devices.where((d) => d.favorite).toList();
      case _DeviceFilter.all:
        return _devices;
    }
  }

  @override
  Widget build(BuildContext context) {
    final onlineCount = _devices.where((d) => d.online).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(onlineCount),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadEquipment,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _buildStatusCard(onlineCount),
                ),
                _buildFilterRow(),
                const SizedBox(height: 4),
                _buildBody(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // هيدر مميز: تدرج أزرق أنيق + ترحيب بالمستخدم زي التصميم المرجعي + جرس تنبيهات
  Widget _buildHeader(int onlineCount) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: AppTheme.headerShadow,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        child: Stack(
          children: [
            // زخارف دائرية شفافة لإحساس تكنولوجي عصري
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.skyBlue.withValues(alpha: 0.14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: widget.onMenuTap,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.menu_rounded,
                                color: Colors.white.withValues(alpha: 0.85),
                                size: 22),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.calendar_today_rounded,
                            size: 11.5, color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 5),
                        Text(
                          formatFullDateTime(_now),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.4,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/robot_face_v2.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, ${widget.userName}',
                                style: AppTheme.display(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'ATOM Flow Systems',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: _openNotifications,
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.notifications_rounded,
                                    color: Colors.white, size: 19),
                                if (_unreadNotifications > 0)
                                  Positioned(
                                    top: -1,
                                    right: -1,
                                    child: Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: AppColors.accentOrange,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppColors.primaryBlueDark,
                                            width: 1.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // كارت حالة النظام: نسبة الأونلاين (بأنيميشن) + الأرقام - بيدّي إحساس داشبورد حي
  Widget _buildStatusCard(int onlineCount) {
    final total = _devices.length;
    final ratio = total == 0 ? 0.0 : onlineCount / total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              height: 62,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 62,
                        height: 62,
                        child: CircularProgressIndicator(
                          value: total == 0 ? 0 : value,
                          strokeWidth: 6,
                          backgroundColor: AppColors.borderGrey,
                          valueColor: AlwaysStoppedAnimation(
                              AppColors.onlineGreen),
                        ),
                      ),
                      Text(
                        '${(value * 100).round()}%',
                        style: AppTheme.dataMono(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onlineGreen,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Status',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$onlineCount of $total devices online',
                    style: AppTheme.display(fontSize: 16.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _miniStatDot(AppColors.onlineGreen, '$onlineCount online'),
                      const SizedBox(width: 12),
                      _miniStatDot(AppColors.offlineRed,
                          '${total - onlineCount} offline'),
                    ],
                  ),
                ],
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _loadEquipment,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.refresh_rounded,
                    size: 18, color: AppColors.primaryBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStatDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LedDot(color: color, size: 7),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }

  // شريط فلاتر سريعة (زي أزرار الأكشن في التصميم المرجعي) بيفلتر قائمة الأجهزة فورًا
  Widget _buildFilterRow() {
    final items = [
      (_DeviceFilter.all, 'All', Icons.apps_rounded),
      (_DeviceFilter.online, 'Online', Icons.wifi_rounded),
      (_DeviceFilter.offline, 'Offline', Icons.wifi_off_rounded),
      (_DeviceFilter.favorite, 'Favorite', Icons.star_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Row(
        children: items.map((item) {
          final (filter, label, icon) = item;
          final selected = _filter == filter;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _filter = filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryBlue
                        : AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryBlue
                          : AppColors.borderGrey,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.primaryBlue.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(icon,
                          size: 18,
                          color: selected ? Colors.white : AppColors.primaryBlue),
                      const SizedBox(height: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppColors.offlineRed, size: 40),
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: AppColors.textGrey)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadEquipment,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_devices.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: 70),
        child: Center(
          child: Text('No devices added yet',
              style: TextStyle(color: AppColors.textGrey)),
        ),
      );
    }

    final filtered = _filteredDevices;
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.filter_alt_off_rounded,
                  color: AppColors.textGrey.withValues(alpha: 0.6), size: 34),
              const SizedBox(height: 10),
              Text('No devices match this filter',
                  style: TextStyle(color: AppColors.textGrey)),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 3 : 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Text(
                _filter == _DeviceFilter.all
                    ? 'Your Devices'
                    : '${_filterLabel(_filter)} Devices',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
            GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return EquipmentCard(
                  key: ValueKey(filtered[index].id),
                  equipment: filtered[index],
                  onUpdated: _onDeviceUpdated,
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _filterLabel(_DeviceFilter filter) {
    switch (filter) {
      case _DeviceFilter.online:
        return 'Online';
      case _DeviceFilter.offline:
        return 'Offline';
      case _DeviceFilter.favorite:
        return 'Favorite';
      case _DeviceFilter.all:
        return 'Your';
    }
  }
}
