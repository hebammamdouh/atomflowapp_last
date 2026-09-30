import 'dart:async';
import 'package:flutter/material.dart';
import '../models/equipment.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;

  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  Equipment? _device;
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // بولينج صامت كل 4 ثواني عشان قرايات الجهاز تفضل لايف من غير ريفريش يدوي
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentRefresh() async {
    if (!mounted || _isLoading) return;
    try {
      final device = await ApiService.getEquipmentById(widget.deviceId);
      if (mounted) setState(() => _device = device);
    } catch (_) {
      // تحديث صامت - مفيش داعي نزعج المستخدم لو فشل مؤقتًا
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final device = await ApiService.getEquipmentById(widget.deviceId);
      setState(() {
        _device = device;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load device data';
        _isLoading = false;
      });
    }
  }

  String _labelForReadingKey(String key) {
    switch (key) {
      case 'flow':
        return 'Flow Rate';
      case 'velocity':
        return 'Velocity';
      case 'totalizer':
        return 'Total Volume';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: AppTheme.headerDecoration(radius: 26),
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
                Expanded(
                  child: Text(
                    _device?.name ?? 'Device Details',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: _load,
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
    if (_error != null || _device == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.offlineRed, size: 40),
            const SizedBox(height: 12),
            Text(_error ?? 'Something went wrong', style: TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final device = _device!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(device),
          const SizedBox(height: 16),
          if (device.readings != null) _readingsCard(device),
          if (device.control != null) _controlInfoCard(device),
          const SizedBox(height: 16),
          _locationCard(device),
          const SizedBox(height: 16),
          _idCard(device),
        ],
      ),
    );
  }

  Widget _statusCard(Equipment device) {
    final statusColor =
        device.online ? AppColors.onlineGreen : AppColors.offlineRed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withValues(alpha: 0.18),
                    statusColor.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                device.online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: statusColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.online ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: device.online
                          ? AppColors.onlineGreen
                          : AppColors.offlineRed,
                    ),
                  ),
                  if (device.lastSeen != null)
                    Text(
                      'Last seen: ${device.lastSeen}',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textGrey),
                    )
                  else
                    Text(
                      'This device has not sent any data yet',
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readingsCard(Equipment device) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Readings',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            ...device.readings!.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(_labelForReadingKey(e.key),
                          style: TextStyle(color: AppColors.textGrey)),
                      const Spacer(),
                      Text(
                        '${e.value.value.toStringAsFixed(2)} ${e.value.unit}',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _controlInfoCard(Equipment device) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Text('Current State',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              Text(
                device.control!.isOn ? 'On' : 'Off',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: device.control!.isOn
                      ? AppColors.onlineGreen
                      : AppColors.offlineRed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationCard(Equipment device) {
    final hasLocation =
        device.location != null && device.location!.label.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.location_on_rounded, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Location',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    hasLocation ? device.location!.label : 'No location set yet',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _idCard(Equipment device) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _idRow('Device ID', device.id),
            if (device.mqttUnid != null) ...[
              const SizedBox(height: 8),
              _idRow('MQTT UID', device.mqttUnid!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _idRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: SelectableText(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}
