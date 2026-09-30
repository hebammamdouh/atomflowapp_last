import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum SidebarItem { dashboard, home, favorite, map, reports, logs, settings, admin }

class AppDrawer extends StatelessWidget {
  final SidebarItem selected;
  final ValueChanged<SidebarItem> onSelect;
  final String userName;
  final bool isAdmin;
  final VoidCallback? onLogout;

  const AppDrawer({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.userName,
    this.isAdmin = false,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cardWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس السايدبار - شعار بالهوية المتدرجة الجديدة
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.headerGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
                child: Image.asset(
                  'assets/images/atom_link_logo.png',
                  height: 38,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _navTile(
            context,
            icon: Icons.grid_view_rounded,
            label: 'Dashboard',
            item: SidebarItem.dashboard,
          ),
          _navTile(
            context,
            icon: Icons.home_rounded,
            label: 'Home',
            item: SidebarItem.home,
          ),
          _navTile(
            context,
            icon: Icons.star_rounded,
            label: 'Favorite',
            item: SidebarItem.favorite,
          ),
          _navTile(
            context,
            icon: Icons.map_rounded,
            label: 'Map / Location',
            item: SidebarItem.map,
          ),
          _navTile(
            context,
            icon: Icons.picture_as_pdf_rounded,
            label: 'Reports',
            item: SidebarItem.reports,
          ),
          _navTile(
            context,
            icon: Icons.bar_chart_rounded,
            label: 'Logs',
            item: SidebarItem.logs,
          ),
          _navTile(
            context,
            icon: Icons.settings_rounded,
            label: 'Settings',
            item: SidebarItem.settings,
          ),
          if (isAdmin)
            _navTile(
              context,
              icon: Icons.admin_panel_settings_rounded,
              label: 'Admin Dashboard',
              item: SidebarItem.admin,
            ),
          const Spacer(),
          Divider(height: 1, color: AppColors.borderGrey),
          SafeArea(
            top: false,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop(); // اقفلي الدروار الأول
                  onLogout?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // الصورة زي ما هي من غير أي تغيير - بس دلوقتي شايلة الهامش
                      // الشفاف اللي كان بيخلي لون خلفية كل شاشة يظهر من وراها
                      // (شوفي assets/images/robot_face_v2.png)
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: AppColors.headerGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/robot_face_v2.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.offlineRed,
                          ),
                        ),
                      ),
                      Icon(Icons.logout_rounded,
                          size: 18, color: AppColors.offlineRed),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required SidebarItem item,
  }) {
    final isSelected = selected == item;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isSelected
            ? AppColors.primaryBlue.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            onSelect(item);
            Navigator.of(context).pop(); // اقفلي الدروار بعد الاختيار
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (isSelected)
                  Container(
                    width: 4,
                    height: 20,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )
                else
                  const SizedBox(width: 14),
                Icon(
                  icon,
                  size: 21,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : AppColors.textGrey,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primaryBlue
                        : AppColors.textDark,
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
