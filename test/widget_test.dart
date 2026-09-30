// اختبار أساسي بيتأكد بس إن التطبيق بيبني من غير ما يطلع استثناء (crash) -
// الاختبار القديم كان بيتنادى على MyApp وعداد (Counter) مش موجودين في التطبيق
// الحقيقي أصلًا (كانوا من مشروع Flutter الافتراضي وقت الإنشاء).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atom_flow_app/main.dart';
import 'package:atom_flow_app/theme/theme_controller.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    // AtomFlowApp بيقرا SharedPreferences (تسجيل الدخول) ومحتاج ThemeController
    // فوقه في الشجرة - زي بالظبط اللي main() بيجهزه فعليًا وقت التشغيل الحقيقي.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeController(),
        child: const AtomFlowApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
