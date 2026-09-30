import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialLabel;

  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialLabel,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _picked;
  late TextEditingController _labelController;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // مركز افتراضي (القاهرة) لو مفيش إحداثيات محفوظة قبل كده
    _picked = LatLng(
      widget.initialLat ?? 30.0444,
      widget.initialLng ?? 31.2357,
    );
    _labelController = TextEditingController(text: widget.initialLabel ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(context).pop({
      'label': _labelController.text.trim(),
      'lat': _picked.latitude,
      'lng': _picked.longitude,
    });
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                      labelText: 'Location Name (e.g. Nasr City Pump Station)',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tap on the map to set the exact spot',
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _picked,
                          initialZoom: 13,
                          onTap: (tapPosition, point) {
                            setState(() => _picked = point);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.atomflowsystems.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _picked,
                                width: 44,
                                height: 44,
                                child: Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.primaryBlue,
                                  size: 44,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 14,
                        bottom: 14,
                        child: Column(
                          children: [
                            _mapFab(Icons.add_rounded, () {
                              _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom + 1);
                            }),
                            const SizedBox(height: 8),
                            _mapFab(Icons.remove_rounded, () {
                              _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom - 1);
                            }),
                          ],
                        ),
                      ),
                    ],
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
                    'Pick Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _confirm,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
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
