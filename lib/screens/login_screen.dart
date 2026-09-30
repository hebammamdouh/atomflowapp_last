import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';

final _pinController = TextEditingController();

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  
  // متغير جديد لتحديد حالة الشاشة (دخول ولا تسجيل جديد)
  bool _isSignUpMode = false;

  // مراحل الأنيميشن
  bool _logoSettled = false;
  bool _showForm = false;

  static const _logoMoveDelay = Duration(milliseconds: 350);
  static const _logoMoveDuration = Duration(milliseconds: 850);
  static const _formRevealDelay = Duration(milliseconds: 250);
  static const _formFadeDuration = Duration(milliseconds: 550);

  @override
  void initState() {
    super.initState();
    _runIntroAnimation();
  }

  Future<void> _runIntroAnimation() async {
    await Future.delayed(_logoMoveDelay);
    if (!mounted) return;
    setState(() => _logoSettled = true);

    await Future.delayed(_logoMoveDuration + _formRevealDelay);
    if (!mounted) return;
    setState(() => _showForm = true);
  }

  // دالة تسجيل الدخول
  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your username and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.login(username, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      setState(() => _errorMessage = result['message']);
    }
  }

  // دالة إنشاء الحساب الجديد
Future<void> _handleSignUp() async {
  final username = _usernameController.text.trim();
  final password = _passwordController.text.trim();
  final pinCode = _pinController.text.trim();

  if (username.isEmpty || password.isEmpty || pinCode.isEmpty) {
    setState(() => _errorMessage = 'Please fill all fields including the PIN');
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  final result = await ApiService.signUp(username, password, pinCode);

  if (!mounted) return;
  setState(() => _isLoading = false);

  if (result['success'] == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: Colors.green.shade700,
      ),
    );
    setState(() {
      _isSignUpMode = false;
      _passwordController.clear();
      _pinController.clear(); // تفريغ الخانة بعد النجاح
    });
  } else {
    setState(() => _errorMessage = result['message']);
  }
}

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
	_pinController.dispose();
    super.dispose();
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.headerGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Positioned(
                    top: -60,
                    left: -50,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -80,
                    right: -60,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.electricBlue.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  AnimatedAlign(
                    duration: _logoMoveDuration,
                    curve: Curves.easeOutCubic,
                    alignment: _logoSettled
                        ? const Alignment(0, -0.66) // رفعت اللوجو سنة بسيطة لفوق عشان يدي براح للكارد
                        : Alignment.center,
                    child: _buildLogo(),
                  ),
                  
                  // 👇 هنا التعديل: استبدلنا Align بـ Positioned و SingleChildScrollView
                  Positioned(
                    top: constraints.maxHeight * 0.35, // تثبيت بداية الكارد من فوق (تحت اللوجو دائماً)
                    left: 0,
                    right: 0,
                    bottom: 0, // بنسيب باقي المساحة تحت مفتوحة عشان السكرول
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      clipBehavior: Clip.none,
                      child: AnimatedOpacity(
                        duration: _formFadeDuration,
                        opacity: _showForm ? 1 : 0,
                        curve: Curves.easeOut,
                        child: AnimatedSlide(
                          duration: _formFadeDuration,
                          curve: Curves.easeOutCubic,
                          // الأنميشن القديم زي ما هو بالظبط
                          offset: _showForm ? Offset.zero : const Offset(0, 0.08),
                          child: IgnorePointer(
                            ignoring: !_showForm,
                            child: _buildForm(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 92,
          height: 92,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            boxShadow: AppTheme.glowShadow,
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/robot_face_v2.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Image.asset(
          'assets/images/atom_link_logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
      ],
    );
  }

Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardWhite.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderGrey),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min, // عشان الكارد مياخدش مساحة زيادة
          children: [
            Text(
              // تغيير العنوان حسب الحالة
              _isSignUpMode ? 'Create Account' : 'Sign In',
              textAlign: TextAlign.center,
              style: AppTheme.display(fontSize: 21, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              // تغيير الوصف حسب الحالة
              _isSignUpMode 
                  ? 'Register a new account to access the dashboard'
                  : 'Enter your credentials to access your dashboard',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              onSubmitted: (_) => _isSignUpMode ? _handleSignUp() : _handleLogin(),
            ),
            
            // 👇👇 التعديل هنا: إضافة خانة الكود (تظهر في حالة الـ Sign Up فقط) 👇👇
            if (_isSignUpMode) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: 'Registration PIN',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
                onSubmitted: (_) => _handleSignUp(),
              ),
            ],
            // 👆👆 نهاية التعديل 👆👆

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: AppColors.offlineRed, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: AppColors.glowGradient),
                boxShadow: AppTheme.glowShadow,
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                onPressed: _isLoading 
                    ? null 
                    : (_isSignUpMode ? _handleSignUp : _handleLogin),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isSignUpMode ? 'Sign Up' : 'Sign In'),
              ),
            ),
            const SizedBox(height: 12),
            // زرار التبديل بين الـ Login والـ Sign Up
            TextButton(
              onPressed: () {
                setState(() {
                  _isSignUpMode = !_isSignUpMode;
                  _errorMessage = null; // مسح أي أخطاء قديمة عند التبديل
                });
              },
              child: Text(
                _isSignUpMode
                    ? 'Already have an account? Sign In'
                    : 'Don\'t have an account? Sign Up',
                style: TextStyle(
                  color: AppColors.electricBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}