import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

// بتولد deviceId ثابت وفريد لكل تنصيبة من التطبيق، وتخزنه محليًا عشان يفضل
// نفسه في كل مرة تفتحي فيها التطبيق - الباك اند بيستخدمه عشان يعرف الجهاز ده
// هو نفسه اللي سجل دخول قبل كده ولا جهاز جديد (حد الـ 3 أجهزة لكل حساب).
class DeviceIdService {
  static const _deviceIdKey = 'device_id';
  static const _deviceNameKey = 'device_name';

  static String? _cachedDeviceId;

  // deviceId ثابت - بيتولد مرة واحدة بس أول ما التطبيق يتفتح، وبعد كده بيترجع
  // نفس القيمة من الـ SharedPreferences طول عمر التنصيبة دي
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = _generateId();
      await prefs.setString(_deviceIdKey, id);
    }
    _cachedDeviceId = id;
    return id;
  }

  // اسم مبدئي مقروء للجهاز (بيتعرض في لوحة الأدمن) - المستخدم يقدر يغيّره لاحقًا
  // لو حبينا نضيف واجهة لتسمية الجهاز، دلوقتي بنولده أوتوماتيك حسب المنصة
  static Future<String> getDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_deviceNameKey);
    if (saved != null && saved.isNotEmpty) return saved;

    final name = _defaultDeviceName();
    await prefs.setString(_deviceNameKey, name);
    return name;
  }

  static String getPlatformLabel() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {
      // Platform مش متاحة في بعض البيئات (زي بعض اختبارات الويب) - نرجع unknown
    }
    return 'unknown';
  }

  static String _defaultDeviceName() {
    final platform = getPlatformLabel();
    switch (platform) {
      case 'android':
        return 'Android Device';
      case 'ios':
        return 'iPhone / iPad';
      case 'macos':
        return 'Mac';
      case 'windows':
        return 'Windows PC';
      case 'linux':
        return 'Linux PC';
      case 'web':
        return 'Web Browser';
      default:
        return 'Unknown Device';
    }
  }

  static String _generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
