import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ==========================================================================
// هوية بصرية "غرفة تحكم" (Control Room) بإحساس أجهزة القياس الصناعية الحقيقية -
// الباليت هنا مستوحاة بالكامل من ألوان لوجو الشركة (الأنبوب الأزرق الداكن +
// قطرة المياه الزرقاء + تدرج الذهبي/البرونزي في كلمة ATOM) بنفس درجة الأناقة
// والغموق اللي في اللوجو الأصلي.
//
// دعم Dark / Light: نفس الهوية والألوان الأساسية، بس بتتقلب لخلفية فاتحة في
// وضع Light بدل الخلفية الداكنة. اللي بيتحكم فيها إمّا AppColors.background
// (تتغيّر حسب الوضع الحالي) أو AppColors.headerGradient (بيفضل ثابت زي هوية
// العلامة التجارية في الاتنين عشان يفضل شكل الهيدر مميز).
// ==========================================================================

// باليت واحدة بكل الألوان المطلوبة - عندنا نسخة dark ونسخة light منها.
class _Palette {
  final Brightness brightness;

  final Color background;
  final Color cardWhite;
  final Color surfaceAlt;
  final Color borderGrey;
  final Color textDark;
  final Color textGrey;

  final Color primaryBlue;
  final Color primaryBlueDark;
  final Color primaryBlueMid;
  final Color skyBlue;
  final Color iceBlue;
  final Color electricBlue;

  final Color accentOrange;
  final Color offlineRed;
  final Color onlineGreen;

  final List<Color> headerGradient;
  final List<Color> glowGradient;

  final List<BoxShadow> cardShadow;
  final List<BoxShadow> headerShadow;
  final List<BoxShadow> glowShadow;

  const _Palette({
    required this.brightness,
    required this.background,
    required this.cardWhite,
    required this.surfaceAlt,
    required this.borderGrey,
    required this.textDark,
    required this.textGrey,
    required this.primaryBlue,
    required this.primaryBlueDark,
    required this.primaryBlueMid,
    required this.skyBlue,
    required this.iceBlue,
    required this.electricBlue,
    required this.accentOrange,
    required this.offlineRed,
    required this.onlineGreen,
    required this.headerGradient,
    required this.glowGradient,
    required this.cardShadow,
    required this.headerShadow,
    required this.glowShadow,
  });
}

// نفس هوية الألوان الأصلية بالظبط - وضع الليل الافتراضي
const _darkPalette = _Palette(
  brightness: Brightness.dark,
  // خلفية التطبيق - أسود مزرق عميق زي شاسيه جهاز صناعي
  background: Color(0xFF070D16),
  // سطح البانل/الكارت - نفس عيلة أزرق الأنبوب في اللوجو، غامق شوية عشان يدي ارتفاع
  cardWhite: Color(0xFF0E1E33),
  // سطح ثانوي أفتح شوية (استخدامات نستد زي أزرار toggle)
  surfaceAlt: Color(0xFF13253F),
  // حدود البانلز - خط رفيع مضيء بلمسة أزرق (حافة الزجاج)
  borderGrey: Color(0xFF1E3557),
  // نصوص - أبيض مزرق ناعم بدل الأبيض الخالص عشان يريح العين
  textDark: Color(0xFFEAF3FC),
  textGrey: Color(0xFF8296B4),
  // أزرق العلامة التجارية - نفس أزرق قطرة المياه في اللوجو
  primaryBlue: Color(0xFF3F74CB),
  primaryBlueDark: Color(0xFF040F1D),
  primaryBlueMid: Color(0xFF0B4C82),
  skyBlue: Color(0xFF5E9AE8),
  iceBlue: Color(0xFF123458),
  electricBlue: Color(0xFF4FA3F5),
  // ذهبي/برونزي - نفس تدرج كلمة ATOM في اللوجو
  accentOrange: Color(0xFFC9974C),
  offlineRed: Color(0xFFFF5470),
  onlineGreen: Color(0xFF2BE6A6),
  headerGradient: [
    Color(0xFF040F1D),
    Color(0xFF0B4C82),
    Color(0xFF5E9AE8),
  ],
  glowGradient: [Color(0xFF3F74CB), Color(0xFF4FA3F5)],
  cardShadow: [
    BoxShadow(
      color: Color(0x59000000), // black @ 0.35
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ],
  headerShadow: [
    BoxShadow(
      color: Color(0x80040F1D), // primaryBlueDark @ 0.5
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ],
  glowShadow: [
    BoxShadow(
      color: Color(0x594FA3F5), // electricBlue @ 0.35
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ],
);

// نفس الهوية بالظبط (نفس أزرق العلامة + نفس الذهبي) بس مقلوبة لخلفية فاتحة -
// الهيدر فضل بنفس تدرج العلامة التجارية عشان يفضل التطبيق متعرف عليه فورًا.
const _lightPalette = _Palette(
  brightness: Brightness.light,
  background: Color(0xFFF3F6FB),
  cardWhite: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFEBF1FA),
  borderGrey: Color(0xFFD9E3F0),
  textDark: Color(0xFF0E1E33),
  textGrey: Color(0xFF5C6C82),
  // نفس أزرق العلامة التجارية، بس درجة أغمق شوية عشان تفضل واضحة فوق الخلفية البيضا
  primaryBlue: Color(0xFF2F5FAE),
  primaryBlueDark: Color(0xFF040F1D),
  primaryBlueMid: Color(0xFF0B4C82),
  skyBlue: Color(0xFF3E7BC4),
  iceBlue: Color(0xFFDCE8F8),
  electricBlue: Color(0xFF2B6FE0),
  accentOrange: Color(0xFFAD7A34),
  offlineRed: Color(0xFFE0304F),
  onlineGreen: Color(0xFF13A97C),
  // الهيدر بيفضل بنفس تدرج العلامة التجارية الغامق زي وضع الليل بالظبط
  headerGradient: [
    Color(0xFF040F1D),
    Color(0xFF0B4C82),
    Color(0xFF5E9AE8),
  ],
  glowGradient: [Color(0xFF2F5FAE), Color(0xFF2B6FE0)],
  cardShadow: [
    BoxShadow(
      color: Color(0x1A0E1E33), // navy @ 0.10 - ظل ناعم بدل الأسود القاتم
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ],
  headerShadow: [
    BoxShadow(
      color: Color(0x40040F1D), // primaryBlueDark @ 0.25
      blurRadius: 22,
      offset: Offset(0, 10),
    ),
  ],
  glowShadow: [
    BoxShadow(
      color: Color(0x402B6FE0), // electricBlue @ 0.25
      blurRadius: 16,
      offset: Offset(0, 5),
    ),
  ],
);

// نقطة الوصول اللي بتستخدمها كل الشاشات (AppColors.background... إلخ) -
// شكل الاستدعاء فضل بالظبط زي ما كان (static)، بس دلوقتي بيرجع لون من الباليت
// الحالية (Dark أو Light) بدل قيمة ثابتة، فلما الباليت تتغيّر كل الشاشات
// اللي بتتبني بعد كده بتاخد اللون الصح تلقائيًا.
class AppColors {
  static _Palette _current = _darkPalette;

  /// تتنادى مرة واحدة في أعلى شجرة الودجتس (main.dart) قبل ما نبني الـ
  /// MaterialApp، عشان كل الشاشات اللي هتتبني بعدها تاخد ألوان الوضع الصح.
  static void applyBrightness(Brightness brightness) {
    _current = brightness == Brightness.dark ? _darkPalette : _lightPalette;
  }

  static Brightness get currentBrightness => _current.brightness;

  static Color get background => _current.background;
  static Color get cardWhite => _current.cardWhite;
  static Color get surfaceAlt => _current.surfaceAlt;
  static Color get borderGrey => _current.borderGrey;
  static Color get textDark => _current.textDark;
  static Color get textGrey => _current.textGrey;

  static Color get primaryBlue => _current.primaryBlue;
  static Color get primaryBlueDark => _current.primaryBlueDark;
  static Color get primaryBlueMid => _current.primaryBlueMid;
  static Color get skyBlue => _current.skyBlue;
  static Color get iceBlue => _current.iceBlue;
  static Color get electricBlue => _current.electricBlue;

  static Color get accentOrange => _current.accentOrange;
  static Color get offlineRed => _current.offlineRed;
  static Color get onlineGreen => _current.onlineGreen;

  static List<Color> get headerGradient => _current.headerGradient;
  static List<Color> get glowGradient => _current.glowGradient;
}

class AppTheme {
  // خط العرض المميز (عناوين، أرقام كبيرة) - طابع تقني/هندسي واضح
  static TextStyle display({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    required Color color,
    double? letterSpacing,
  }) {
    return GoogleFonts.rajdhani(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: 1.05,
    );
  }

  // خط مونوسبيس لقراءات الأجهزة - التوقيع المميز اللي بيدي إحساس شاشة قياس حقيقية
  static TextStyle dataMono({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    required Color color,
    bool glow = false,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.1,
      shadows: glow
          ? [Shadow(color: color.withValues(alpha: 0.55), blurRadius: 10)]
          : null,
    );
  }

  static ThemeData dark() => _build(_darkPalette);
  static ThemeData light() => _build(_lightPalette);

  static ThemeData _build(_Palette p) {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primaryBlue,
        brightness: p.brightness,
        primary: p.primaryBlue,
        secondary: p.electricBlue,
        surface: p.cardWhite,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: p.textDark,
        displayColor: p.textDark,
      ),
      dividerColor: p.borderGrey,
      appBarTheme: AppBarTheme(
        backgroundColor: p.primaryBlueDark,
        foregroundColor: p.textDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.rajdhani(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.cardWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p.borderGrey),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.cardWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        titleTextStyle: GoogleFonts.rajdhani(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: p.textDark,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 13.5,
          color: p.textGrey,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.primaryBlue,
        textColor: p.textDark,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.cardWhite,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceAlt,
        contentTextStyle: GoogleFonts.inter(color: p.textDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.borderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.electricBlue, width: 1.6),
        ),
        labelStyle: GoogleFonts.inter(
          color: p.textGrey,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.inter(
          color: p.textGrey.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        iconColor: p.textGrey,
        prefixIconColor: p.textGrey,
        suffixIconColor: p.textGrey,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.electricBlue,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      iconTheme: IconThemeData(color: p.textGrey),
    );
  }

  // ظل ناعم للكاردز - بيتغيّر حسب الوضع الحالي (Dark/Light)
  static List<BoxShadow> get cardShadow => AppColors._current.cardShadow;

  // ظل أعمق للهيدر المتدرج
  static List<BoxShadow> get headerShadow => AppColors._current.headerShadow;

  // توهج سيان للعناصر البارزة (أزرار، عناصر مختارة)
  static List<BoxShadow> get glowShadow => AppColors._current.glowShadow;

  // توهج حالة (أونلاين/أوفلاين/تحذير) بيتحط خلف الأيقونة أو النقطة الدائرية
  static List<BoxShadow> statusGlow(Color color, {double blur = 8}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.55),
        blurRadius: blur,
        spreadRadius: 0.5,
      ),
    ];
  }

  // ديكوريشن هيدر متدرج جاهز يتكرر في كل شاشات التطبيق لهوية بصرية موحدة
  static BoxDecoration headerDecoration({double radius = 30}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: AppColors.headerGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(radius),
        bottomRight: Radius.circular(radius),
      ),
      boxShadow: headerShadow,
    );
  }
}

// نقطة حالة LED مضيئة - العنصر البصري المتكرر اللي بيوحّد شكل "أونلاين/أوفلاين"
// في كل الشاشات (الهوم، الداشبورد، الكروت، الخرايط، القوائم)
class LedDot extends StatelessWidget {
  final Color color;
  final double size;

  const LedDot({super.key, required this.color, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: AppTheme.statusGlow(color, blur: size * 0.9),
      ),
    );
  }
}
