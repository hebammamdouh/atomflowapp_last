import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import 'admin_dashboard_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'favorite_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'logs_screen.dart';
import 'map_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  SidebarItem _selected = SidebarItem.home;
  String _userName = '...';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = await ApiService.getMe();
    if (!mounted) return;
    setState(() {
      _userName = user?['name'] ?? 'User';
      _isAdmin = user?['role'] == 'admin';
    });
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  Future<void> _logout() async {
    await ApiService.logout();
    await ApiService.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget _buildSelectedScreen() {
    switch (_selected) {
      case SidebarItem.dashboard:
        return AnalyticsDashboardScreen(
          onMenuTap: _openDrawer,
          onViewFullMap: () => setState(() => _selected = SidebarItem.map),
        );
      case SidebarItem.home:
        return HomeScreen(
          onMenuTap: _openDrawer,
          userName: _userName,
          onOpenDashboard: () => setState(() => _selected = SidebarItem.dashboard),
        );
      case SidebarItem.favorite:
        return FavoriteScreen(onMenuTap: _openDrawer);
      case SidebarItem.map:
        return MapScreen(onMenuTap: _openDrawer);
      case SidebarItem.reports:
        return ReportsScreen(onMenuTap: _openDrawer);
      case SidebarItem.logs:
        return LogsScreen(onMenuTap: _openDrawer);
      case SidebarItem.settings:
        return SettingsScreen(onMenuTap: _openDrawer, onLogout: _logout);
      case SidebarItem.admin:
        return AdminDashboardScreen(onMenuTap: _openDrawer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: AppDrawer(
        selected: _selected,
        userName: _userName,
        isAdmin: _isAdmin,
        onSelect: (item) => setState(() => _selected = item),
        onLogout: _logout,
      ),
      body: SafeArea(
        top: false,
        child: _buildSelectedScreen(),
      ),
    );
  }
}
