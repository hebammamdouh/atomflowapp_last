// نسخة الويب: بتنزّل ملف الـ CSV مباشرة من المتصفح (زي أي تحميل عادي) -
// بتستخدم package:web + dart:js_interop بدل dart:html القديمة (متوقفة/مش
// متوافقة مع بناء أندرويد/iOS، وده اللي كان بيوقف الـ Release build).
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<String> downloadCsv(String filename, String csvContent) async {
  final blob = web.Blob(
    [csvContent.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return 'Downloaded $filename';
}
