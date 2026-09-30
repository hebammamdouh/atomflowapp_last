import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/equipment.dart';
import '../models/app_notification.dart';
import 'device_id_service.dart';
 
class ApiService {
  // غيري ده لعنوان السيرفر بتاعك وقت التشغيل الحقيقي
  // للتجربة على محاكي أندرويد استخدمي: http://10.0.2.2:4000/api
  // للتجربة على جهاز حقيقي/iOS simulator استخدمي IP الجهاز بتاعك على نفس الشبكة
  static const String baseUrl = 'http://86.48.2.17:4000/api';
 
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
 
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
 
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
 
  // تسجيل الدخول - بنبعت deviceId ثابت بتاع الجهاز ده (متولد مرة واحدة ومتخزن
  // محليًا، شوفي device_id_service.dart) عشان الباك اند يفرض حد الـ 3 أجهزة لكل
  // حساب. لو الحساب ده وصل للحد الأقصى، الباك اند بيرجع 403 مع code
  // 'DEVICE_LIMIT_REACHED' ورسالة واضحة بنعرضها زي ما هي في شاشة اللوجين
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      print('=== جاري الاتصال بالرابط: $url ===');
 
      final deviceId = await DeviceIdService.getDeviceId();
      final deviceName = await DeviceIdService.getDeviceName();
      final platform = DeviceIdService.getPlatformLabel();
 
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': platform,
        }),
      );
 
      final data = jsonDecode(response.body);
 
      if (response.statusCode == 200) {
        await _saveToken(data['token']);
        return {'success': true, 'user': data['user']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Something went wrong',
          'code': data['code'],
        };
      }
    } catch (e) {
      print('=== حدث خطأ أثناء الاتصال: $e ===');
      // إرجاع الخطأ عشان الواجهة توقف تحميل وتعرضه
      return {'success': false, 'message': 'خطأ في الاتصال: $e'};
    }
  }
 
  // تسجيل الخروج - بيحرر مكان الجهاز ده من الـ 3 أماكن المتاحة للحساب على طول
  // من غير ما تحتاجي تستني أدمن يعمله لك يدوي
  static Future<void> logout() async {
    try {
      final token = await _getToken();
      final deviceId = await DeviceIdService.getDeviceId();
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'deviceId': deviceId}),
      );
    } catch (_) {
      // لو فشل النداء (مثلاً مفيش نت)، منمنعش المستخدم من تسجيل الخروج محليًا -
      // ببساطة هتفضل الـ session بتاعته مسجلة لحد ما تنتهي صلاحية التوكن
    }
  }
  
  static Future<Map<String, dynamic>> signUp(
      String username, String password, String pinCode) async {
    try {
      final url = Uri.parse('$baseUrl/auth/signup');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username, 
          'password': password,
          'pinCode': pinCode // إرسال الكود
        }),
      );
 
      final data = jsonDecode(response.body);
 
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error occurred.'};
    }
  }
 
  // جلب كل الأجهزة
  static Future<List<Equipment>> getEquipment() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/equipment'),
      headers: {'Authorization': 'Bearer $token'},
    );
 
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List devicesJson = data['devices'];
      return devicesJson.map((d) => Equipment.fromJson(d)).toList();
    } else {
      // لو الاشتراك مقفول (402 SUBSCRIPTION_INACTIVE) أو أي خطأ تاني، نبعت رسالة
      // السيرفر الحقيقية بدل رسالة عامة، عشان اليوزر يفهم سبب القفل بالظبط
      String message = 'Failed to fetch equipment data';
      try {
        final data = jsonDecode(response.body);
        if (data['message'] != null) message = data['message'];
      } catch (_) {}
      throw Exception(message);
    }
  }
 
  // التحكم في جهاز (relay/valve on/off)
  static Future<Equipment> controlDevice(String id, String state) async {
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('$baseUrl/equipment/$id/control'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'state': state}),
    );
 
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Equipment.fromJson(data['device']);
    } else {
      throw Exception('Failed to execute command');
    }
  }
 
  static Future<bool> isLoggedIn() async {
    final token = await _getToken();
    return token != null;
  }
 
  // بيانات المستخدم الحالي (لصفحة Settings)
  static Future<Map<String, dynamic>?> getMe() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['user'];
    }
    return null;
  }
 
  // إضافة جهاز جديد - الـ id بيتولد أوتوماتيك من الباك اند
  static Future<Equipment> addEquipment({
    required String name,
    required String type, // 'sensor' | 'relay' | 'valve'
    String? mqttUnid,
    String? locationLabel,
    double? lat,
    double? lng,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/equipment'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'type': type,
        if (mqttUnid != null && mqttUnid.isNotEmpty) 'mqttUnid': mqttUnid,
        if (locationLabel != null || lat != null)
          'location': {
            'label': locationLabel ?? '',
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
          },
      }),
    );
 
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Equipment.fromJson(data['device']);
    } else {
      throw Exception('Failed to add device');
    }
  }
 
  // جلب جهاز واحد بالتفصيل (لصفحة تفاصيل العداد)
  static Future<Equipment> getEquipmentById(String id) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/equipment/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Equipment.fromJson(data['device']);
    } else {
      throw Exception('Failed to load device data');
    }
  }
 
  // تعديل اسم/لوكيشن جهاز موجود (من قائمة خيارات الكارت)
  static Future<Equipment> updateEquipment(
    String id, {
    String? name,
    DeviceLocation? location,
  }) async {
    final token = await _getToken();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (location != null) {
      body['location'] = {
        'label': location.label,
        if (location.lat != null) 'lat': location.lat,
        if (location.lng != null) 'lng': location.lng,
      };
    }
 
    final response = await http.patch(
      Uri.parse('$baseUrl/equipment/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
 
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Equipment.fromJson(data['device']);
    } else {
      throw Exception('Failed to update device');
    }
  }
 
  // تفعيل/إلغاء المفضلة لجهاز - بتظهر بعدين في شاشة Favorite بالسايد بار
  static Future<Equipment> setFavorite(String id, bool favorite) async {
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('$baseUrl/equipment/$id/favorite'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'favorite': favorite}),
    );
 
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Equipment.fromJson(data['device']);
    } else {
      throw Exception('Failed to update favorite');
    }
  }
 
  // سجل قرايات عداد معين - لشاشة Reports وتحميل الـ CSV
  static Future<List<DeviceLogEntry>> getDeviceLogs(String id,
      {int? limit}) async {
    final token = await _getToken();
    final uri = Uri.parse('$baseUrl/equipment/$id/logs').replace(
      queryParameters: limit != null ? {'limit': '$limit'} : null,
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
 
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List logsJson = data['logs'];
      return logsJson.map((l) => DeviceLogEntry.fromJson(l)).toList();
    } else {
      throw Exception('Failed to load device logs');
    }
  }
 
  // ===== Notifications (جرس الهوم) =====
  // أونلاين/أوفلاين + تنبيهات فلو high/low + تنبيه التوتال - كل ده بيتولد
  // تلقائي من الباك اند، الشاشة هنا بس بتجيبه وتعرضه
  static Future<Map<String, dynamic>> getNotifications({int? limit}) async {
    final token = await _getToken();
    final uri = Uri.parse('$baseUrl/notifications').replace(
      queryParameters: limit != null ? {'limit': '$limit'} : null,
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
 
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List notifsJson = data['notifications'];
      return {
        'notifications':
            notifsJson.map((n) => AppNotification.fromJson(n)).toList(),
        'unreadCount': data['unreadCount'] as int? ?? 0,
      };
    } else {
      throw Exception('Failed to load notifications');
    }
  }
 
  static Future<void> markNotificationRead(String id) async {
    final token = await _getToken();
    await http.patch(
      Uri.parse('$baseUrl/notifications/$id/read'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }
 
  static Future<void> markAllNotificationsRead() async {
    final token = await _getToken();
    await http.post(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }
 
  // ===== Alert Settings (Flow High / Flow Low / Total Threshold) =====
  // القيم دي بتتحدد من اليوزر في شاشة الـ Settings - لو null يبقى التنبيه ده مقفول
  static Future<Map<String, dynamic>> getAlertSettings() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/settings'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data['settings']);
    } else {
      throw Exception('Failed to load alert settings');
    }
  }
 
  static Future<Map<String, dynamic>> updateAlertSettings({
    double? flowHigh,
    bool clearFlowHigh = false,
    double? flowLow,
    bool clearFlowLow = false,
    double? totalThreshold,
    bool clearTotalThreshold = false,
  }) async {
    final token = await _getToken();
    final body = <String, dynamic>{};
    if (clearFlowHigh) {
      body['flowHigh'] = null;
    } else if (flowHigh != null) {
      body['flowHigh'] = flowHigh;
    }
    if (clearFlowLow) {
      body['flowLow'] = null;
    } else if (flowLow != null) {
      body['flowLow'] = flowLow;
    }
    if (clearTotalThreshold) {
      body['totalThreshold'] = null;
    } else if (totalThreshold != null) {
      body['totalThreshold'] = totalThreshold;
    }
 
    final response = await http.patch(
      Uri.parse('$baseUrl/settings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
 
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data['settings']);
    } else {
      throw Exception('Failed to update alert settings');
    }
  }
 
  // ===== Admin Dashboard (role: 'admin' بس) =====
  // كل الدوال دي بترجع رسالة خطأ واضحة لو السيرفر رد بـ 403 (يعني اليوزر الحالي
  // مش أدمن) - الشاشة بتتعامل مع الحالة دي عادي زي أي خطأ تاني
 
  static Future<List<Map<String, dynamic>>> getAdminUsers() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final List usersJson = data['users'];
      return usersJson.map((u) => Map<String, dynamic>.from(u)).toList();
    }
    throw Exception(data['message'] ?? 'Failed to load users');
  }
 
  static Future<List<Map<String, dynamic>>> getUserSessions(
      String userId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/users/$userId/sessions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final List sessionsJson = data['sessions'];
      return sessionsJson.map((s) => Map<String, dynamic>.from(s)).toList();
    }
    throw Exception(data['message'] ?? 'Failed to load sessions');
  }
 
  static Future<List<Equipment>> getUserMeters(String userId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/users/$userId/meters'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final List metersJson = data['meters'];
      return metersJson.map((m) => Equipment.fromJson(m)).toList();
    }
    throw Exception(data['message'] ?? 'Failed to load meters');
  }
 
  // إنهاء جلسة جهاز معين (فك الارتباط) - بيحرر مكانه لجهاز جديد
  static Future<void> terminateSession(String userId, String sessionId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/users/$userId/sessions/$sessionId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to terminate session');
    }
  }
 
  // قفل/تفعيل الاشتراك (الكارت/الخدمة) بتاعة يوزر معين
  static Future<void> updateUserSubscription(
      String userId, bool isSubscribed) async {
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/users/$userId/subscription'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'isSubscribed': isSubscribed}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to update subscription');
    }
  }
 
  // إضافة عداد/كارت جديد مباشرة ليوزر معين من لوحة الأدمن
  static Future<Equipment> addMeterForUser({
    required String userId,
    required String name,
    required String type,
    String? mqttUnid,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/admin/users/$userId/meters'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'type': type,
        if (mqttUnid != null && mqttUnid.isNotEmpty) 'mqttUnid': mqttUnid,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return Equipment.fromJson(data['device']);
    }
    throw Exception(data['message'] ?? 'Failed to add meter');
  }
 
  // حذف/مسح عداد بالكامل من النظام
  static Future<void> removeMeter(String deviceId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/meters/$deviceId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to remove meter');
    }
  }
}