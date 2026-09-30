# ATOM Flow App (Flutter)

## هيكل التطبيق

```
lib/
  main.dart
  theme/app_theme.dart              # الألوان + خط Plus Jakarta Sans (google_fonts)
  models/equipment.dart             # يشمل location (lat/lng), onlineSince, offlineSince
  services/api_service.dart
  utils/time_format.dart            # تنسيق "منذ متى" / "مدة الأونلاين"

  screens/
    login_screen.dart               # أنيميشن اللوجو
    main_shell.dart                 # الـ Shell + السايدبار
    analytics_dashboard_screen.dart # NEW: صفحة "Dashboard" التحليلية
    home_screen.dart                # صفحة "Home" بكروت الأجهزة
    map_screen.dart                 # NEW: خريطة حقيقية (OpenStreetMap) لكل الأجهزة اللي ليها لوكيشن
    location_picker_screen.dart     # NEW: اختيار لوكيشن على الخريطة (للإضافة والتعديل)
    favorite_screen.dart / reports_screen.dart  # لسه فاضيين
    settings_screen.dart
    add_device_screen.dart          # فيه اختيار لوكيشن بالخريطة دلوقتي
    device_detail_screen.dart

  widgets/
    app_drawer.dart                 # Dashboard, Home, Favorite, Map/Location, Reports, Settings
    equipment_card.dart             # زرار (⋮) بيفتح: Rename / Edit location / Status details
    coming_soon_placeholder.dart
```

## المهم: Dashboard vs Home

- **Dashboard** = صفحة تحليلية (Analytics) فيها: إحصائيات سريعة، Live Flow Trend (بيتجمع لحظياً من وقت ما تفتحي الصفحة - مش بيانات تاريخية محفوظة لسه)، توزيع Online/Offline (Donut)، أعلى الأجهزة تدفقاً (Bar chart)، تنبيهات حية (مبنية على: جهاز أوفلاين / سرعة عالية)، معاينة خريطة مصغرة، وقائمة الأجهزة الأوفلاين.
- **Home** = نفس كروت الأجهزة القديمة (بتصميم محسّن) للتحكم والمتابعة السريعة.

> **ملحوظة مهمة عن الـ Trend chart:** الباك اند حالياً بيحتفظ بآخر قراية بس (مفيش تخزين تاريخي / Database). فالـ "Live Flow Trend" بيتبني من القرايات اللحظية طول ما التطبيق فاتح، مش من تاريخ محفوظ. لو عايزة Trend حقيقي عبر أيام/أسابيع، الخطوة الجاية هي تخزين القرايات في قاعدة بيانات (Time-series) في الباك اند.

## الخريطة (Map / Location)

- بتستخدم `flutter_map` + خرائط OpenStreetMap (مفيش API key مطلوب)
- بتعرض بس الأجهزة اللي ليها `location.lat` و `location.lng` محددين
- تقدري تحددي اللوكيشن من: شاشة "Add New Device" أو من قائمة خيارات أي كارت (⋮ > Edit location)
- الدوس على أي جهاز في القايمة تحت الخريطة بيركز الخريطة عليه

## خيارات الكارت (⋮)

كل كارت في صفحة Home فيه زرار ⋮ في الركن، بيفتح قائمة فيها:
- **Rename device** - تغيير الاسم
- **Edit location** - فتح الخريطة لتحديد/تعديل اللوكيشن
- **Status details** - يوريكي الجهاز أونلاين/أوفلاين من إمتى بالظبط (الباك اند بيسجل `onlineSince`/`offlineSince` بدقة عند كل تغيير حالة فعلي، مش مجرد آخر رسالة وصلت)

## التشغيل

```bash
cd flutter_app
flutter pub get
flutter run
```

اضبطي عنوان السيرفر في `lib/services/api_service.dart`:
```dart
static const String baseUrl = 'http://10.0.2.2:4000/api'; // محاكي أندرويد
```

## الخطوات الجاية

1. تخزين تاريخي حقيقي للقرايات (Database) عشان الـ Reports و Trend يبقوا بيانات فعلية عبر وقت طويل مش بس Session الحالي
2. صفحة Favorite تفعيل فعلي
3. Push notifications للتنبيهات (Offline / High Velocity) بدل ما تكون Live في الداشبورد بس
4. WebSocket بدل الـ Polling كل 5 ثواني
