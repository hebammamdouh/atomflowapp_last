import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: const AtomFlowApp(),
    ),
  );
}

class AtomFlowApp extends StatelessWidget {
  const AtomFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    // بنسمع لتغييرات المظهر (فاتح/غامق/حسب النظام) - أي تغيير هنا بيعيد بناء
    // الشجرة كلها من هنا لتحت، فكل الشاشات بتاخد ألوان الوضع الجديد أوتوماتيك.
    final themeController = context.watch<ThemeController>();
    final isDark = themeController.isDark;

    // لازم نحدّث الباليت الحالية *قبل* ما أي شاشة تتبني، عشان كل استدعاءات
    // AppColors.xxx خلال الـ build تاخد لون الوضع الصح.
    AppColors.applyBrightness(isDark ? Brightness.dark : Brightness.light);

    return MaterialApp(
      title: 'ATOM Flow Systems',
      debugShowCheckedModeBanner: false,
      theme: isDark ? AppTheme.dark() : AppTheme.light(),
      home: const _StartupGate(),
    );
  }
}

// يقرر نروح على شاشة اللوجين ولا الداشبورد على حسب لو فيه توكن محفوظ
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await ApiService.isLoggedIn();
    setState(() {
      _loggedIn = loggedIn;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _loggedIn ? const MainShell() : const LoginScreen();
  }
}
