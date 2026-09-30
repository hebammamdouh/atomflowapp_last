// واجهة موحدة لتحميل/حفظ ملف CSV سواء الأبليكشن شغال ويب أو موبايل/ديسكتوب.
// الاختيار بين النسختين بيحصل وقت الـ compile (conditional import) - مفيش أي حاجة
// إضافية مطلوبة وقت التشغيل.
export 'csv_downloader_stub.dart'
    if (dart.library.html) 'csv_downloader_web.dart'
    if (dart.library.io) 'csv_downloader_io.dart';
