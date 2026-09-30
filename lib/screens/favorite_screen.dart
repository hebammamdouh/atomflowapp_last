import 'package:flutter/material.dart';
import '../models/equipment.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/equipment_card.dart';
import '../widgets/simple_header.dart';

// شاشة "Favorite" - بتعرض بس الأجهزة اللي اتحطتلها نجمة (favorite) من كارت الهوم
class FavoriteScreen extends StatefulWidget {
  final VoidCallback onMenuTap;
  const FavoriteScreen({super.key, required this.onMenuTap});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<Equipment> _favorites = [];
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
      final devices = await ApiService.getEquipment();
      setState(() {
        _favorites = devices.where((d) => d.favorite).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load favorites';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return SimpleHeader(
      title: 'Favorite',
      subtitle: 'Your starred devices',
      icon: Icons.star_rounded,
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
    );
  }

  // بيتنادى لما أي كارت يتحدث - لو الفيفورت اتشالت من هنا نفسه نشيلها من
  // الليستة فورًا، ولو تحديث تاني (تحكم/اسم) نزامنها في مكانها
  void _onDeviceUpdated(Equipment updated) {
    setState(() {
      if (!updated.favorite) {
        _favorites.removeWhere((d) => d.id == updated.id);
      } else {
        final index = _favorites.indexWhere((d) => d.id == updated.id);
        if (index != -1) _favorites[index] = updated;
      }
    });
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Center(
            child: Column(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: AppColors.offlineRed, size: 40),
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: AppColors.textGrey)),
                const SizedBox(height: 12),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ],
      );
    }
    if (_favorites.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.star_border_rounded,
                      size: 42, color: AppColors.accentOrange),
                ),
                const SizedBox(height: 16),
                Text(
                  'No favorite meters yet',
                  style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Tap the star icon on any device card in Home to add it here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textGrey, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: _favorites.length,
          itemBuilder: (context, index) {
            return EquipmentCard(
              key: ValueKey(_favorites[index].id),
              equipment: _favorites[index],
              onUpdated: _onDeviceUpdated,
            );
          },
        );
      },
    );
  }
}
