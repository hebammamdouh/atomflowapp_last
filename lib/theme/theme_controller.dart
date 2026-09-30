import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// أوضاع المظهر المتاحة للمستخدم من شاشة الإعدادات
enum AppThemeMode { light, dark, system }

const String _prefsKey = 'atom_flow_theme_mode';

// بيتحكم في اختيار المستخدم لمظهر التطبيق (فاتح/غامق/حسب النظام)، بيحفظ
// الاختيار محليًا، وبيبقى عارف الـ brightness "الفعلي" الحالي حتى لو
// المستخدم مختار "حسب النظام" (بيتابع تغيير الوضع في نظام الموبايل نفسه).
class ThemeController extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.dark; // نفس افتراضي التطبيق قبل كده
  bool _loaded = false;

  AppThemeMode get mode => _mode;
  bool get isLoaded => _loaded;

  ThemeController() {
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
        () {
      if (_mode == AppThemeMode.system) {
        notifyListeners();
      }
    };
    _load();
  }

  // الـ brightness الفعلي اللي المفروض التطبيق يظهر بيه دلوقتي
  Brightness get effectiveBrightness {
    switch (_mode) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
      case AppThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  bool get isDark => effectiveBrightness == Brightness.dark;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null) {
        _mode = AppThemeMode.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => AppThemeMode.dark,
        );
      }
    } catch (_) {
      // لو فشل تحميل التفضيل المحفوظ، هنفضل على الوضع الافتراضي (Dark)
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // مش مشكلة لو الحفظ فشل، هيفضل الاختيار شغال للسيشن الحالية
    }
  }
}
