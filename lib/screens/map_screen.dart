import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/equipment.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/simple_header.dart';
import 'device_detail_screen.dart';

class MapScreen extends StatefulWidget {
  final VoidCallback onMenuTap;
  const MapScreen({super.key, required this.onMenuTap});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<Equipment> _devices = [];
  bool _isLoading = true;
  Equipment? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final devices = await ApiService.getEquipment();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Equipment> get _located =>
      _devices.where((d) => d.location?.hasCoordinates == true).toList();

  void _focusDevice(Equipment device) {
    setState(() => _selected = device);
    _mapController.move(
      LatLng(device.location!.lat!, device.location!.lng!),
      15,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SimpleHeader(
          title: 'Map / Location',
          subtitle: '${_located.length} device${_located.length == 1 ? '' : 's'} pinned',
          icon: Icons.map_rounded,
          onMenuTap: widget.onMenuTap,
          actions: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 19),
              ),
            ),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _located.isEmpty
                  ? _buildEmptyState()
                  : _buildMapWithList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.map_rounded, size: 42, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 16),
          Text(
            'No devices have a location set yet',
            style: TextStyle(color: AppColors.textGrey, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'Open a device card > options > Edit location',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMapWithList() {
    final center = LatLng(
      _located.first.location!.lat!,
      _located.first.location!.lng!,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 320,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: center, initialZoom: 12),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.atomflowsystems.app',
                  ),
                  MarkerLayer(
                    markers: _located.map((device) {
                      final isSelected = _selected?.id == device.id;
                      return Marker(
                        point: LatLng(
                          device.location!.lat!,
                          device.location!.lng!,
                        ),
                        width: 140,
                        height: 58,
                        alignment: Alignment.bottomCenter,
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = device),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.cardWhite,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryBlue
                                        : AppColors.borderGrey,
                                  ),
                                  boxShadow: AppTheme.cardShadow,
                                ),
                                child: Text(
                                  device.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Icon(
                                Icons.location_on_rounded,
                                size: 34,
                                color: device.online
                                    ? AppColors.onlineGreen
                                    : AppColors.offlineRed,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  children: [
                    _mapFab(Icons.add_rounded, () {
                      _mapController.move(_mapController.camera.center,
                          _mapController.camera.zoom + 1);
                    }),
                    const SizedBox(height: 8),
                    _mapFab(Icons.remove_rounded, () {
                      _mapController.move(_mapController.camera.center,
                          _mapController.camera.zoom - 1);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppColors.borderGrey),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Devices with location (${_located.length})',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _located.length,
            itemBuilder: (context, index) {
              final device = _located[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(
                    Icons.location_on_rounded,
                    color: device.online
                        ? AppColors.onlineGreen
                        : AppColors.offlineRed,
                  ),
                  title: Text(device.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text(
                    device.location!.label.isNotEmpty
                        ? device.location!.label
                        : '${device.location!.lat!.toStringAsFixed(4)}, ${device.location!.lng!.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.info_outline_rounded,
                        color: AppColors.textGrey, size: 20),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DeviceDetailScreen(deviceId: device.id),
                        ),
                      );
                    },
                  ),
                  onTap: () => _focusDevice(device),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _mapFab(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppColors.cardWhite,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20, color: AppColors.textDark),
        ),
      ),
    );
  }
}
