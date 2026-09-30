import 'package:flutter/material.dart';
import '../models/equipment.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/csv_downloader.dart';
import '../utils/time_format.dart';

// شاشة "Logs" - سجل قرايات كل عداد (Flow / Velocity / Totalizer) بالوقت، مع
// إمكانية تحميل السجل كملف CSV - منفصلة عن شاشة "Reports" (تقرير الـ PDF)
class LogsScreen extends StatefulWidget {
  final VoidCallback onMenuTap;
  const LogsScreen({super.key, required this.onMenuTap});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Equipment> _meters = [];
  Equipment? _selectedMeter;
  List<DeviceLogEntry> _logs = [];

  bool _isLoadingMeters = true;
  bool _isLoadingLogs = false;
  bool _isDownloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMeters();
  }

  // بس الأجهزة اللي عندها قرايات (النوع sensor) - الريلاي/الفالف مالهاش سجل قرايات
  Future<void> _loadMeters() async {
    setState(() {
      _isLoadingMeters = true;
      _error = null;
    });
    try {
      final devices = await ApiService.getEquipment();
      final meters = devices.where((d) => d.type == 'sensor').toList();
      setState(() {
        _meters = meters;
        _isLoadingMeters = false;
        if (meters.isNotEmpty) {
          _selectedMeter = meters.first;
        }
      });
      if (_selectedMeter != null) _loadLogs();
    } catch (e) {
      setState(() {
        _error = 'Failed to load meters';
        _isLoadingMeters = false;
      });
    }
  }

  Future<void> _loadLogs() async {
    final meter = _selectedMeter;
    if (meter == null) return;
    setState(() {
      _isLoadingLogs = true;
      _error = null;
    });
    try {
      final logs = await ApiService.getDeviceLogs(meter.id, limit: 500);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoadingLogs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load readings log';
        _isLoadingLogs = false;
      });
    }
  }

  void _onMeterChanged(Equipment? meter) {
    if (meter == null) return;
    setState(() => _selectedMeter = meter);
    _loadLogs();
  }

  Future<void> _downloadCsv() async {
    final meter = _selectedMeter;
    if (meter == null || _logs.isEmpty) return;

    setState(() => _isDownloading = true);
    try {
      final buffer = StringBuffer();
      buffer.writeln('Device,Timestamp,Flow (m3/h),Velocity (m/s),Totalizer (m3)');
      for (final log in _logs) {
        final ts = log.timestamp?.toIso8601String() ?? '';
        buffer.writeln(
            '${meter.name},$ts,${log.flow.toStringAsFixed(3)},${log.velocity.toStringAsFixed(3)},${log.totalizer.toStringAsFixed(3)}');
      }

      final safeName = meter.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filename = 'logs_${safeName}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final result = await downloadCsv(filename, buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export CSV')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.borderGrey)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.menu_rounded, color: AppColors.textDark),
              onPressed: widget.onMenuTap,
            ),
            Text(
              'Logs',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.textGrey),
              onPressed: _isLoadingMeters ? null : _loadMeters,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingMeters) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _meters.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.offlineRed, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadMeters, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_meters.isEmpty) {
      return Center(
        child: Text('No meters available yet',
            style: TextStyle(color: AppColors.textGrey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _meterSelector(),
        _logsSummaryBar(),
        Divider(height: 1, color: AppColors.borderGrey),
        Expanded(child: _logsList()),
      ],
    );
  }

  Widget _meterSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGrey),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Equipment>(
            isExpanded: true,
            value: _selectedMeter,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textGrey),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            items: _meters.map((meter) {
              return DropdownMenuItem<Equipment>(
                value: meter,
                child: Row(
                  children: [
                    Icon(Icons.sensors_rounded,
                        size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(meter.name, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: _onMeterChanged,
          ),
        ),
      ),
    );
  }

  Widget _logsSummaryBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isLoadingLogs
                  ? 'Loading readings…'
                  : '${_logs.length} reading${_logs.length == 1 ? '' : 's'} logged',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: (_logs.isEmpty || _isDownloading) ? null : _downloadCsv,
            icon: _isDownloading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logsList() {
    if (_isLoadingLogs) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.offlineRed, size: 36),
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 10),
            TextButton(onPressed: _loadLogs, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_logs.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No readings logged yet for this meter.\nLogs are recorded automatically as data arrives from the device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
        itemCount: _logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) => _logRow(_logs[index]),
      ),
    );
  }

  Widget _logRow(DeviceLogEntry log) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 13, color: AppColors.textGrey),
              const SizedBox(width: 5),
              Text(
                formatLogTimestamp(log.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _logValue('Flow', '${log.flow.toStringAsFixed(2)} m³/h'),
              _logValue('Velocity', '${log.velocity.toStringAsFixed(2)} m/s'),
              _logValue('Total', '${log.totalizer.toStringAsFixed(2)} m³'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _logValue(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10.5, color: AppColors.textGrey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}
