// نسخة الموبايل/الديسكتوب لتحميل ملف CSV.
//
// على أندرويد/iOS: بنفتح شاشة المشاركة/الحفظ بتاعة النظام نفسه (نفس الحاجة
// بالظبط اللي بتفتح لما تنزلي تقرير الـ PDF عن طريق Printing.layoutPdf) -
// المستخدم بيحدد بنفسه فين هيحفظ الملف (Save to Files/Drive/إلخ)، وده بيدي
// نتيجة نجاح/فشل موثوقة من النظام نفسه بدل ما نعتمد على مكتبة MediaStore
// كانت بترجع "فشل" أحيانًا حتى لو الملف اتحفظ فعلًا في Downloads.
//
// على الديسكتوب (ويندوز/ماك/لينكس): بيتحفظ مباشرة في مجلد Downloads الحقيقي
// بتاع الجهاز زي ما كان قبل كده - مفيش مشكلة اتبلغ عنها هنا.
import 'dart:io';

import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:share_plus/share_plus.dart';

Future<String> downloadCsv(String filename, String csvContent) async {
  if (Platform.isAndroid || Platform.isIOS) {
    return _downloadCsvMobile(filename, csvContent);
  }
  return _downloadCsvDesktop(filename, csvContent);
}

Future<String> _downloadCsvMobile(String filename, String csvContent) async {
  final tempDir = await path_provider.getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/$filename');
  await tempFile.writeAsString(csvContent);

  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile(tempFile.path, mimeType: 'text/csv')],
      subject: filename,
    ),
  );

  // بنبني الرسالة من رد فعل النظام نفسه (مش من تخمين مكتبة تالتة) - ده اللي
  // بيمنع رسالة "failed" الغلط اللي كانت بتظهر مع إن الملف نزل فعلًا
  switch (result.status) {
    case ShareResultStatus.success:
      return 'Saved $filename';
    case ShareResultStatus.dismissed:
      return 'Cancelled — $filename was not saved';
    // ignore: unreachable_switch_default
    default:
      return 'Saved $filename';
  }
}

Future<String> _downloadCsvDesktop(String filename, String csvContent) async {
  Directory? targetDir;
  try {
    // متاحة على ويندوز/ماك/لينكس - بترجع مجلد Downloads الحقيقي بتاع الجهاز.
    targetDir = await path_provider.getDownloadsDirectory();
  } catch (_) {
    targetDir = null;
  }

  targetDir ??= await path_provider.getApplicationDocumentsDirectory();

  final file = File('${targetDir.path}/$filename');
  await file.writeAsString(csvContent);
  return 'Saved to ${file.path}';
}
