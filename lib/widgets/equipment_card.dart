import 'package:flutter/material.dart';
import '../models/equipment.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../screens/device_detail_screen.dart';
import '../screens/location_picker_screen.dart';
import '../utils/time_format.dart';

class EquipmentCard extends StatefulWidget {
  final Equipment equipment;
  final ValueChanged<Equipment>? onUpdated;

  const EquipmentCard({super.key, required this.equipment, this.onUpdated});

  @override
  State<EquipmentCard> createState() => _EquipmentCardState();
}

class _EquipmentCardState extends State<EquipmentCard> {
  late Equipment _equipment;
  bool _isToggling = false;
  bool _isTogglingFavorite = false;

  @override
  void initState() {
    super.initState();
    _equipment = widget.equipment;
  }

  // لو الليستة فوق اتحدثت (فلترة/ريفريش) لازم الكارت ياخد أحدث نسخة من البيانات
  // بدل ما يفضل عالق على أول نسخة اتعمل بيها initState (ده كان سبب باج فلتر Online)
  @override
  void didUpdateWidget(covariant EquipmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.equipment.id != widget.equipment.id ||
        oldWidget.equipment != widget.equipment) {
      _equipment = widget.equipment;
    }
  }

  // أي تحديث محلي للكارت (فيفورت/تحكم/اسم/لوكيشن) لازم يترفع للشاشة الأب
  // عشان الليستة الأصلية (وبالتالي فلتر Favorite/Online) تفضل متزامنة
  void _updateEquipment(Equipment updated) {
    setState(() => _equipment = updated);
    widget.onUpdated?.call(updated);
  }

  // تفعيل/إلغاء "مفضلة" مباشرة من الكارت - العداد يظهر بعدها في شاشة Favorite بالسايد بار
  // وكمان بيترفع للشاشة الأب عشان فلتر Favorite في الهوم يفضل متزامن فورًا
  Future<void> _toggleFavorite() async {
    final newValue = !_equipment.favorite;
    setState(() => _isTogglingFavorite = true);
    _updateEquipment(_equipment.copyWith(favorite: newValue)); // تحديث فوري في الشكل
    try {
      final updated = await ApiService.setFavorite(_equipment.id, newValue);
      if (mounted) _updateEquipment(updated);
    } catch (e) {
      if (mounted) {
        _updateEquipment(_equipment.copyWith(favorite: !newValue));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update favorite')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingFavorite = false);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'relay':
        return Icons.settings_input_component_rounded;
      case 'valve':
        return Icons.plumbing_rounded;
      default:
        return Icons.sensors_rounded;
    }
  }

  Future<void> _toggleControl(String newState) async {
    setState(() => _isToggling = true);
    try {
      final updated =
          await ApiService.controlDevice(_equipment.id, newState);
      _updateEquipment(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send command, please try again')),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  String _labelForReadingKey(String key) {
    switch (key) {
      case 'flow':
        return 'Flow';
      case 'velocity':
        return 'Velocity';
      case 'totalizer':
        return 'Total';
      default:
        return key;
    }
  }

  IconData _iconForReadingKey(String key) {
    switch (key) {
      case 'flow':
        return Icons.waves_rounded;
      case 'velocity':
        return Icons.speed_rounded;
      case 'totalizer':
        return Icons.donut_large_rounded;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس الكارت: أيقونة النوع + اسم الجهاز + حالة الاتصال + زرار خيارات
          InkWell(
            onTap: () => _openDetails(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryBlue.withValues(alpha: 0.14),
                          AppColors.skyBlue.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(_iconForType(_equipment.type),
                        size: 18, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _equipment.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: AppColors.textDark,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            child: LedDot(
                              color: _equipment.online
                                  ? AppColors.onlineGreen
                                  : AppColors.offlineRed,
                              size: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _isTogglingFavorite ? null : _toggleFavorite,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        _equipment.favorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 20,
                        color: _equipment.favorite
                            ? AppColors.accentOrange
                            : AppColors.textGrey,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showOptions(context),
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.more_vert_rounded,
                          size: 18, color: AppColors.textGrey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.borderGrey),
          // الجسم: إما تحكم (relay/valve) أو قرايات (sensor)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: _equipment.control != null
                ? _buildControlBody()
                : InkWell(
                    onTap: () => _openDetails(context),
                    child: _buildReadingsBody(),
                  ),
          ),
        ],
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceDetailScreen(deviceId: _equipment.id),
      ),
    );
  }

  // قائمة خيارات الكارت: تغيير الاسم / اللوكيشن / معلومات الحالة
  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderGrey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _equipment.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _optionTile(
                icon: Icons.edit_outlined,
                label: 'Rename device',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _renameDialog(context);
                },
              ),
              _optionTile(
                icon: Icons.location_on_outlined,
                label: 'Edit location',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _editLocation(context);
                },
              ),
              _optionTile(
                icon: Icons.access_time_rounded,
                label: 'Status details',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _statusDialog(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _optionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryBlue),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
      onTap: onTap,
    );
  }

  Future<void> _renameDialog(BuildContext context) async {
    final controller = TextEditingController(text: _equipment.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Device'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Device Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _equipment.name) {
      try {
        final updated = await ApiService.updateEquipment(_equipment.id, name: newName);
        _updateEquipment(updated);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to rename device')),
          );
        }
      }
    }
  }

  Future<void> _editLocation(BuildContext context) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: _equipment.location?.lat,
          initialLng: _equipment.location?.lng,
          initialLabel: _equipment.location?.label,
        ),
      ),
    );

    if (result != null) {
      try {
        final updated = await ApiService.updateEquipment(
          _equipment.id,
          location: DeviceLocation(
            label: result['label'] ?? '',
            lat: result['lat'],
            lng: result['lng'],
          ),
        );
        _updateEquipment(updated);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update location')),
          );
        }
      }
    }
  }

  void _statusDialog(BuildContext context) {
    final isOnline = _equipment.online;
    final sinceText = isOnline
        ? formatDuration(_equipment.onlineSince)
        : formatDuration(_equipment.offlineSince);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: isOnline ? AppColors.onlineGreen : AppColors.offlineRed,
            ),
            const SizedBox(width: 8),
            Text(isOnline ? 'Online' : 'Offline'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOnline
                  ? 'Online for $sinceText'
                  : 'Offline for $sinceText',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _equipment.lastSeen != null
                  ? 'Last data received ${formatTimeAgo(_equipment.lastSeen)}'
                  : 'No data received yet',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBody() {
    final control = _equipment.control!;
    return Column(
      children: [
        Text(
          control.label,
          style: TextStyle(
              color: AppColors.textGrey,
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        _isToggling
            ? const SizedBox(
                height: 34,
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2)))
            : Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _toggleButton(
                        label: 'Off',
                        selected: !control.isOn,
                        color: AppColors.offlineRed,
                        onTap: () => _toggleControl('off'),
                      ),
                    ),
                    Expanded(
                      child: _toggleButton(
                        label: 'On',
                        selected: control.isOn,
                        color: AppColors.onlineGreen,
                        onTap: () => _toggleControl('on'),
                      ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _toggleButton({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: selected ? Colors.white : AppColors.textGrey,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildReadingsBody() {
    final readings = _equipment.readings ?? {};
    return Column(
      children: readings.entries.map((entry) {
        final reading = entry.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Icon(_iconForReadingKey(entry.key),
                  size: 15, color: AppColors.primaryBlue),
              const SizedBox(width: 7),
              Text(
                _labelForReadingKey(entry.key),
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textGrey,
                ),
              ),
              const Spacer(),
              Text(
                reading.value.toStringAsFixed(2),
                style: AppTheme.dataMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.electricBlue,
                  glow: true,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                reading.unit,
                style: TextStyle(
                    fontSize: 10.5, color: AppColors.textGrey),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
