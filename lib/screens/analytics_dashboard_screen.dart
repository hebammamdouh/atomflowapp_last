import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/equipment.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import 'device_detail_screen.dart';

class _AlertItem {
  final String deviceName;
  final String type;
  final String severity; // 'Low' | 'Medium' | 'High'
  final String time;

  _AlertItem({
    required this.deviceName,
    required this.type,
    required this.severity,
    required this.time,
  });
}

// نطاقات الفترة الزمنية المتاحة أعلى الداشبورد
enum _RangeOption { today, week, month }

extension on _RangeOption {
  String get label {
    switch (this) {
      case _RangeOption.today:
        return 'Today';
      case _RangeOption.week:
        return '7 Days';
      case _RangeOption.month:
        return '30 Days';
    }
  }

  int get days {
    switch (this) {
      case _RangeOption.today:
        return 1;
      case _RangeOption.week:
        return 7;
      case _RangeOption.month:
        return 30;
    }
  }

  // كام قراية نجيب من الـ API لكل عداد - بيكبر مع الفترة عشان يغطيها كويس
  int get logLimit {
    switch (this) {
      case _RangeOption.today:
        return 300;
      case _RangeOption.week:
        return 1000;
      case _RangeOption.month:
        return 2000;
    }
  }

  // عدد نقاط الترند اللي هنرسمها (بنجمع القرايات جوه كل نقطة/bucket)
  int get bucketCount {
    switch (this) {
      case _RangeOption.today:
        return 12;
      case _RangeOption.week:
        return 7;
      case _RangeOption.month:
        return 30;
    }
  }
}

class AnalyticsDashboardScreen extends StatefulWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onViewFullMap;

  const AnalyticsDashboardScreen({
    super.key,
    required this.onMenuTap,
    required this.onViewFullMap,
  });

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  List<Equipment> _devices = [];
  bool _isLoading = true;
  Timer? _timer;
  DateTime? _lastTrendLoad;

  // فلاتر أعلى الصفحة - null يعني "كل العدادات"
  String? _selectedMeterId;
  _RangeOption _range = _RangeOption.week;

  // إعدادات التنبيهات (Flow High / Flow Low / Total Threshold) من شاشة الإعدادات
  Map<String, dynamic> _alertSettings = {};

  // بيانات الترند بعد التحميل والتجميع في buckets زمنية
  bool _isTrendLoading = false;
  List<FlSpot> _flowSpots = [];
  List<FlSpot> _totalSpots = [];
  List<DateTime> _bucketTimes = [];
  double _flowHighInRange = 0;
  double _flowLowInRange = 0;
  double _todaysTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadAlertSettings();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Equipment> get _sensors =>
      _devices.where((d) => d.type == 'sensor').toList();

  Equipment? _findSensor(String id) {
    for (final d in _sensors) {
      if (d.id == id) return d;
    }
    return null;
  }

  String get _flowUnit =>
      _sensors.isNotEmpty ? (_sensors.first.readings?['flow']?.unit ?? 'm³/h') : 'm³/h';
  String get _totalUnit =>
      _sensors.isNotEmpty ? (_sensors.first.readings?['totalizer']?.unit ?? 'm³') : 'm³';

  double get _combinedTotalNow => _sensors.fold<double>(
      0, (sum, d) => sum + (d.readings?['totalizer']?.value ?? 0));

  double? get _selectedMeterTotalNow {
    if (_selectedMeterId == null) return null;
    return _findSensor(_selectedMeterId!)?.readings?['totalizer']?.value;
  }

  double? get _flowHighThreshold =>
      (_alertSettings['flowHigh'] as num?)?.toDouble();
  double? get _flowLowThreshold =>
      (_alertSettings['flowLow'] as num?)?.toDouble();
  double? get _totalThreshold =>
      (_alertSettings['totalThreshold'] as num?)?.toDouble();

  Future<void> _load() async {
    try {
      final devices = await ApiService.getEquipment();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
      // بنحدّث الترند مش أوفتر من مرة كل 30 ثانية عشان منكترش على السيرفر
      final now = DateTime.now();
      if (_lastTrendLoad == null ||
          now.difference(_lastTrendLoad!) > const Duration(seconds: 30)) {
        _lastTrendLoad = now;
        _loadTrends();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAlertSettings() async {
    try {
      final s = await ApiService.getAlertSettings();
      if (mounted) setState(() => _alertSettings = s);
    } catch (_) {
      // مفيش مشكلة لو فشل - هنعتبر مفيش حدود متحطة (مفيش إندكيتور هيظهر)
    }
  }

  void _onMeterFilterChanged(String? meterId) {
    setState(() => _selectedMeterId = meterId);
    _lastTrendLoad = DateTime.now();
    _loadTrends();
  }

  void _onRangeChanged(_RangeOption range) {
    if (_range == range) return;
    setState(() => _range = range);
    _lastTrendLoad = DateTime.now();
    _loadTrends();
  }

  Future<void> _loadTrends() async {
    final sensors = _sensors;
    if (sensors.isEmpty) {
      setState(() {
        _flowSpots = [];
        _totalSpots = [];
        _bucketTimes = [];
        _todaysTotal = 0;
        _flowHighInRange = 0;
        _flowLowInRange = 0;
      });
      return;
    }

    setState(() => _isTrendLoading = true);
    try {
      final targets = _selectedMeterId == null
          ? sensors
          : sensors.where((m) => m.id == _selectedMeterId).toList();

      final logsByMeter = await Future.wait(
        targets.map((m) => ApiService.getDeviceLogs(m.id, limit: _range.logLimit)),
      );

      final now = DateTime.now();
      final rangeStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: _range.days - 1));
      final todayStart = DateTime(now.year, now.month, now.day);

      // فلترة كل سجل على الفترة المختارة فقط، وترتيبه زمنيًا
      final filtered = logsByMeter.map((logs) {
        final l = logs
            .where((e) => e.timestamp != null && !e.timestamp!.isBefore(rangeStart))
            .toList();
        l.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
        return l;
      }).toList();

      // تقسيم الفترة لعدد بسيط من الـ buckets الزمنية عشان نرسم خط ترند واحد
      // حتى لو في أكتر من عداد مجمّعين مع بعض (وضع "All Meters")
      final bucketCount = _range.bucketCount;
      final totalSpan = now.difference(rangeStart).inMilliseconds;
      final bucketMs = (totalSpan / bucketCount).round().clamp(1, 1 << 40);

      final flowSpots = <FlSpot>[];
      final totalSpots = <FlSpot>[];
      final bucketTimes = <DateTime>[];

      for (var b = 0; b < bucketCount; b++) {
        final bucketStart = rangeStart.add(Duration(milliseconds: bucketMs * b));
        final bucketEnd = b == bucketCount - 1
            ? now
            : rangeStart.add(Duration(milliseconds: bucketMs * (b + 1)));
        bucketTimes.add(bucketStart);

        double flowSum = 0;
        double totalSum = 0;
        for (final logs in filtered) {
          final inBucket = logs
              .where((e) =>
                  !e.timestamp!.isBefore(bucketStart) && e.timestamp!.isBefore(bucketEnd))
              .toList();
          if (inBucket.isNotEmpty) {
            flowSum += inBucket.map((e) => e.flow).reduce((a, c) => a + c) /
                inBucket.length;
          }
          // آخر قراية توتاليزر معروفة لحد نهاية الـ bucket ده (تراكمي)
          final upToBucket =
              logs.where((e) => e.timestamp!.isBefore(bucketEnd)).toList();
          if (upToBucket.isNotEmpty) {
            totalSum += upToBucket.last.totalizer;
          }
        }
        flowSpots.add(FlSpot(b.toDouble(), flowSum));
        totalSpots.add(FlSpot(b.toDouble(), totalSum));
      }

      // توتال اليوم = القراية الحالية - آخر قراية معروفة قبل بداية اليوم
      // (يعني الاستهلاك اللي حصل النهاردة بس، من غير التوتال المتراكم كله)
      double todaysTotal = 0;
      for (final logs in filtered) {
        if (logs.isEmpty) continue;
        final beforeToday =
            logs.where((e) => e.timestamp!.isBefore(todayStart)).toList();
        final baseline =
            beforeToday.isNotEmpty ? beforeToday.last.totalizer : logs.first.totalizer;
        final delta = logs.last.totalizer - baseline;
        todaysTotal += delta > 0 ? delta : 0;
      }

      final flowValues = flowSpots.map((s) => s.y).where((v) => v > 0).toList();

      if (!mounted) return;
      setState(() {
        _flowSpots = flowSpots;
        _totalSpots = totalSpots;
        _bucketTimes = bucketTimes;
        _todaysTotal = todaysTotal;
        _flowHighInRange = flowValues.isEmpty ? 0 : flowValues.reduce((a, b) => a > b ? a : b);
        _flowLowInRange = flowValues.isEmpty ? 0 : flowValues.reduce((a, b) => a < b ? a : b);
        _isTrendLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isTrendLoading = false);
    }
  }

  int get _onlineCount => _devices.where((d) => d.online).length;
  int get _offlineCount => _devices.where((d) => !d.online).length;

  List<_AlertItem> get _alerts {
    final alerts = <_AlertItem>[];
    for (final d in _devices) {
      if (!d.online) {
        alerts.add(_AlertItem(
          deviceName: d.name,
          type: 'Device Offline',
          severity: 'Medium',
          time: formatTimeAgo(d.offlineSince ?? d.lastSeen),
        ));
      }
      final velocity = d.readings?['velocity']?.value;
      if (velocity != null && velocity > 5) {
        alerts.add(_AlertItem(
          deviceName: d.name,
          type: 'High Velocity',
          severity: 'High',
          time: formatTimeAgo(d.lastSeen),
        ));
      }
    }
    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                    children: [
                      _filterBar(),
                      const SizedBox(height: 14),
                      _statsGrid(),
                      const SizedBox(height: 14),
                      _totalSection(),
                      const SizedBox(height: 14),
                      _flowSection(),
                      const SizedBox(height: 14),
                      _sectionCard(
                        title: 'Device Status Distribution',
                        child: _statusDonutChart(),
                      ),
                      const SizedBox(height: 14),
                      _alertsCard(),
                      const SizedBox(height: 14),
                      _mapPreviewCard(),
                      const SizedBox(height: 14),
                      _offlineListCard(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
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
            Positioned(
              top: -35,
              right: -25,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 18),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu_rounded, color: Colors.white),
                      onPressed: widget.onMenuTap,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Dashboard',
                          style: AppTheme.display(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'Analytics & live insights',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _load,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.refresh_rounded,
                            color: Colors.white, size: 19),
                      ),
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

  // ===== شريط الفلاتر أعلى الصفحة: اختيار العداد + الفترة الزمنية =====
  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors_rounded, size: 16, color: AppColors.primaryBlue),
              const SizedBox(width: 6),
              Text('Meter',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textGrey)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderGrey),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: _selectedMeterId,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textGrey),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.layers_rounded, size: 16, color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        const Text('All Meters'),
                      ],
                    ),
                  ),
                  ..._sensors.map((m) => DropdownMenuItem<String?>(
                        value: m.id,
                        child: Row(
                          children: [
                            LedDot(color: m.online ? AppColors.onlineGreen : AppColors.offlineRed, size: 8),
                            const SizedBox(width: 8),
                            Expanded(child: Text(m.name, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      )),
                ],
                onChanged: _onMeterFilterChanged,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.date_range_rounded, size: 16, color: AppColors.primaryBlue),
              const SizedBox(width: 6),
              Text('Period',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textGrey)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: _RangeOption.values.map((r) => _rangeChip(r)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _rangeChip(_RangeOption r) {
    final selected = _range == r;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onRangeChanged(r),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryBlue.withValues(alpha: 0.14) : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primaryBlue : AppColors.borderGrey,
              width: selected ? 1.2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            r.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? AppColors.primaryBlue : AppColors.textGrey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsGrid() {
    final stats = [
      (
        'Total Devices',
        '${_devices.length}',
        Icons.dns_rounded,
        AppColors.primaryBlue
      ),
      ('Online', '$_onlineCount', Icons.wifi_rounded, AppColors.onlineGreen),
      ('Offline', '$_offlineCount', Icons.wifi_off_rounded, AppColors.offlineRed),
      (
        'Active Alerts',
        '${_alerts.length}',
        Icons.warning_amber_rounded,
        AppColors.accentOrange
      ),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final s = stats[index];
          final color = s.$4 as Color;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderGrey),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(s.$3 as IconData, color: color, size: 15),
                const SizedBox(width: 7),
                Text(
                  s.$2 as String,
                  style: AppTheme.dataMono(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  s.$1 as String,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionCard({required String title, String? subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              if (subtitle != null) ...[
                const SizedBox(width: 6),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ===== قسم الـ Total: 3 مؤشرات + ترند بإندكيتور تجاوز الحد =====
  Widget _totalSection() {
    final selectedName = _selectedMeterId == null
        ? null
        : _findSensor(_selectedMeterId!)?.name;
    final exceeded = _totalThreshold != null &&
        _totalSpots.isNotEmpty &&
        _totalSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) >= _totalThreshold!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.electricBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Total',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              if (exceeded)
                _alertPill('Alert exceeded', AppColors.offlineRed),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _totalTile(
                  'All Meters',
                  '${_combinedTotalNow.toStringAsFixed(1)} $_totalUnit',
                  Icons.layers_rounded,
                  AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _totalTile(
                  selectedName ?? 'Pick a meter',
                  _selectedMeterTotalNow != null
                      ? '${_selectedMeterTotalNow!.toStringAsFixed(1)} $_totalUnit'
                      : '—',
                  Icons.sensors_rounded,
                  AppColors.electricBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _totalTile(
                  'Today',
                  '${_todaysTotal.toStringAsFixed(1)} $_totalUnit',
                  Icons.today_rounded,
                  AppColors.accentOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isTrendLoading
              ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
              : _trendChart(
                  spots: _totalSpots,
                  lineColor: AppColors.electricBlue,
                  thresholdY: _totalThreshold,
                  thresholdColor: AppColors.offlineRed,
                  breachIsAbove: true,
                ),
        ],
      ),
    );
  }

  Widget _totalTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTheme.dataMono(fontSize: 13, fontWeight: FontWeight.w700, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 9.5, color: AppColors.textGrey, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _alertPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // ===== قسم الـ Flow: ترند + إندكيتورز High/Low =====
  Widget _flowSection() {
    final highBreached = _flowHighThreshold != null && _flowHighInRange >= _flowHighThreshold!;
    final lowBreached = _flowLowThreshold != null && _flowLowInRange > 0 && _flowLowInRange <= _flowLowThreshold!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Flow Trend',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _legendDot('Flow', AppColors.primaryBlue),
              const SizedBox(width: 14),
              _legendDot('High limit', AppColors.offlineRed, dashed: true),
              const SizedBox(width: 14),
              _legendDot('Low limit', AppColors.accentOrange, dashed: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _flowIndicator(
                  'High',
                  '${_flowHighInRange.toStringAsFixed(1)} $_flowUnit',
                  highBreached ? AppColors.offlineRed : AppColors.onlineGreen,
                  highBreached,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _flowIndicator(
                  'Low',
                  '${_flowLowInRange.toStringAsFixed(1)} $_flowUnit',
                  lowBreached ? AppColors.accentOrange : AppColors.onlineGreen,
                  lowBreached,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isTrendLoading
              ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
              : _trendChart(
                  spots: _flowSpots,
                  lineColor: AppColors.primaryBlue,
                  thresholdY: _flowHighThreshold,
                  thresholdColor: AppColors.offlineRed,
                  secondThresholdY: _flowLowThreshold,
                  secondThresholdColor: AppColors.accentOrange,
                  breachIsAbove: true,
                ),
        ],
      ),
    );
  }

  // نقطة/شرطة صغيرة ملونة جنب اسم العنصر - نفس فكرة legend اللي بيبقى تحت
  // عنوان الشارت (نقطة مصمتة للخط الأساسي، شرطة متقطعة لحدود التنبيه)
  Widget _legendDot(String label, Color color, {bool dashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed)
          Container(width: 10, height: 2, color: color)
        else
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _flowIndicator(String label, String value, Color color, bool breached) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            breached ? Icons.warning_rounded : Icons.check_circle_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: AppTheme.dataMono(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(label,
                    style: TextStyle(fontSize: 9.5, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== شارت ترند عام يستخدمه قسم الـ Total والـ Flow مع خطوط/نقاط تنبيه =====
  Widget _trendChart({
    required List<FlSpot> spots,
    required Color lineColor,
    double? thresholdY,
    Color thresholdColor = Colors.red,
    double? secondThresholdY,
    Color secondThresholdColor = Colors.orange,
    bool breachIsAbove = true,
  }) {
    if (spots.length < 2) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Text(
            'Not enough data yet for this period',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
        ),
      );
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final topBound = [maxY, thresholdY ?? 0].reduce((a, b) => a > b ? a : b) * 1.15 + 0.5;

    final labelStep = (_bucketTimes.length / 6).ceil().clamp(1, 1000);

    return SizedBox(
      height: 170,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: topBound,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (topBound / 4).clamp(0.5, double.infinity),
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.borderGrey,
              strokeWidth: 1,
              dashArray: [3, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= _bucketTimes.length || i % labelStep != 0) {
                    return const SizedBox.shrink();
                  }
                  final t = _bucketTimes[i];
                  String label;
                  switch (_range) {
                    case _RangeOption.today:
                      label = '${t.hour.toString().padLeft(2, '0')}:00';
                      break;
                    case _RangeOption.week:
                      label = formatShortWeekday(t);
                      break;
                    case _RangeOption.month:
                      label = '${t.day}';
                      break;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label, style: TextStyle(fontSize: 9, color: AppColors.textGrey)),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(horizontalLines: [
            if (thresholdY != null)
              HorizontalLine(
                y: thresholdY,
                color: thresholdColor.withValues(alpha: 0.7),
                strokeWidth: 1.4,
                dashArray: [6, 4],
              ),
            if (secondThresholdY != null)
              HorizontalLine(
                y: secondThresholdY,
                color: secondThresholdColor.withValues(alpha: 0.7),
                strokeWidth: 1.4,
                dashArray: [6, 4],
              ),
          ]),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 2.5,
              belowBarData: BarAreaData(show: true, color: lineColor.withValues(alpha: 0.12)),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  final breachesHigh = thresholdY != null &&
                      breachIsAbove &&
                      spot.y >= thresholdY;
                  final breachesLow = secondThresholdY != null &&
                      spot.y > 0 &&
                      spot.y <= secondThresholdY;
                  if (breachesHigh) {
                    return FlDotCirclePainter(
                      radius: 4.5,
                      color: thresholdColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  }
                  if (breachesLow) {
                    return FlDotCirclePainter(
                      radius: 4.5,
                      color: secondThresholdColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  }
                  return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusDonutChart() {
    if (_devices.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(child: Text('No devices', style: TextStyle(color: AppColors.textGrey))),
      );
    }
    return Row(
      children: [
        SizedBox(
          height: 130,
          width: 130,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 38,
              sections: [
                PieChartSectionData(
                  value: _onlineCount.toDouble(),
                  color: AppColors.onlineGreen,
                  title: '',
                  radius: 20,
                ),
                PieChartSectionData(
                  value: _offlineCount.toDouble(),
                  color: AppColors.offlineRed,
                  title: '',
                  radius: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legendRow(AppColors.onlineGreen, 'Online',
                  '${((_onlineCount / _devices.length) * 100).toStringAsFixed(0)}%'),
              const SizedBox(height: 8),
              _legendRow(AppColors.offlineRed, 'Offline',
                  '${((_offlineCount / _devices.length) * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendRow(Color color, String label, String value) {
    return Row(
      children: [
        LedDot(color: color, size: 10),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
        const Spacer(),
        Text(value, style: AppTheme.dataMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      ],
    );
  }

  Widget _alertsCard() {
    final alerts = _alerts;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Live System Alerts',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          if (alerts.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Text('No active alerts',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
            )
          else
            ...alerts.take(6).map((a) => _alertRow(a)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _alertRow(_AlertItem a) {
    Color severityColor;
    switch (a.severity) {
      case 'High':
        severityColor = AppColors.offlineRed;
        break;
      case 'Medium':
        severityColor = AppColors.accentOrange;
        break;
      default:
        severityColor = AppColors.textGrey;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.warning_rounded, size: 17, color: severityColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.deviceName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                Text(a.type, style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(a.severity,
                    style: TextStyle(
                        fontSize: 10.5, color: severityColor, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 3),
              Text(a.time, style: TextStyle(fontSize: 9.5, color: AppColors.textGrey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mapPreviewCard() {
    final located = _devices.where((d) => d.location?.hasCoordinates == true).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
            child: Row(
              children: [
                const Text('Map Overview',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const Spacer(),
                TextButton(
                  onPressed: widget.onViewFullMap,
                  child: const Text('View Full Map',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 160,
            child: located.isEmpty
                ? Center(
                    child: Text('No devices pinned yet',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                  )
                : IgnorePointer(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          located.first.location!.lat!,
                          located.first.location!.lng!,
                        ),
                        initialZoom: 11,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.atomflowsystems.app',
                        ),
                        MarkerLayer(
                          markers: located.map((d) {
                            return Marker(
                              point: LatLng(d.location!.lat!, d.location!.lng!),
                              width: 26,
                              height: 26,
                              child: Icon(
                                Icons.location_on_rounded,
                                color: d.online
                                    ? AppColors.onlineGreen
                                    : AppColors.offlineRed,
                                size: 26,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _offlineListCard() {
    final offline = _devices.where((d) => !d.online).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Offline Devices',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          if (offline.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Text('All devices are online 🎉',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
            )
          else
            ...offline.map((d) => InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DeviceDetailScreen(deviceId: d.id)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.offlineRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.wifi_off_rounded,
                              size: 16, color: AppColors.offlineRed),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.name,
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(
                                'Last seen ${formatTimeAgo(d.lastSeen)}',
                                style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.textGrey),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
