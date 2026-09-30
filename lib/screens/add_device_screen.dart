import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'location_picker_screen.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _nameController = TextEditingController();
  final _mqttUnidController = TextEditingController();
  String _type = 'sensor';
  bool _isSaving = false;
  String? _error;

  Map<String, dynamic>? _pickedLocation; // {label, lat, lng}

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null) {
      setState(() => _pickedLocation = result);
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a device name');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final device = await ApiService.addEquipment(
        name: _nameController.text.trim(),
        type: _type,
        mqttUnid: _mqttUnidController.text.trim(),
        locationLabel: _pickedLocation?['label'],
        lat: _pickedLocation?['lat'],
        lng: _pickedLocation?['lng'],
      );
      if (!mounted) return;
      Navigator.of(context).pop(device);
    } catch (e) {
      setState(() {
        _error = 'Failed to add device';
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mqttUnidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'The device ID is generated automatically once saved.',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Device Name',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Device Type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'sensor', child: Text('Meter (readings)')),
                    DropdownMenuItem(
                        value: 'relay', child: Text('Relay (control)')),
                    DropdownMenuItem(
                        value: 'valve', child: Text('Valve (control)')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'sensor'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _mqttUnidController,
                  decoration: const InputDecoration(
                    labelText:
                        'MQTT UID (optional - for real devices connected via MQTT)',
                    prefixIcon: Icon(Icons.sensors_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickLocation,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderGrey),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.location_on_outlined,
                              color: AppColors.primaryBlue, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _pickedLocation != null &&
                                    (_pickedLocation!['label'] as String)
                                        .isNotEmpty
                                ? _pickedLocation!['label']
                                : (_pickedLocation != null
                                    ? 'Location pinned on map'
                                    : 'Set location on map (optional)'),
                            style: TextStyle(
                              color: _pickedLocation != null
                                  ? AppColors.textDark
                                  : AppColors.textGrey,
                              fontWeight: _pickedLocation != null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.textGrey),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!,
                      style: TextStyle(
                          color: AppColors.offlineRed, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient:
                        LinearGradient(colors: AppColors.glowGradient),
                    boxShadow: AppTheme.glowShadow,
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
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
          padding: const EdgeInsets.fromLTRB(6, 6, 16, 18),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: const Icon(Icons.add_circle_outline_rounded,
                      color: Colors.white, size: 19),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Add New Device',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
