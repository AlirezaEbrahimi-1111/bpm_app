import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'features/auth/auth_service.dart';
import 'features/shell/main_shell.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'core/network/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.init();
  runApp(const BpmApp());
}

class BpmApp extends StatelessWidget {
  const BpmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'یکتا همراهان ملک',
      debugShowCheckedModeBanner: false,
      textDirection: TextDirection.rtl,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [
        PersianMaterialLocalizations.delegate,
        PersianCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6D28D9)),
        useMaterial3: true,
        fontFamily: 'Vazir',
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  // رنگ‌های برند (هماهنگ با نسخه وب)
  static const _primary = Color(0xFF6D28D9); // بنفش اصلی
  static const _primaryLight = Color(0xFF8B5CF6); // بنفش روشن
  static const _accent = Color(0xFF10B981); // سبز برند
  static const _ink = Color(0xFF1A1A2E); // متن تیره

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── پس‌زمینه تزئینی (خطوط مدار + نقاط) ──
          Positioned.fill(child: CustomPaint(painter: _BackgroundPainter())),
          // ── محتوا ──
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // ── لوگو ──
                  _buildLogo(),
                  const SizedBox(height: 20),

                  // ── نام شرکت ──
                  const Text(
                    'یکتا همراهان ملک',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── شعار ──
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                        fontFamily: 'Vazir',
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'مدیریت یکپارچه فرآیندها',
                          style: TextStyle(color: _primary),
                        ),
                        TextSpan(text: ' در یک نگاه'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── چیپ‌های ویژگی ──
                  _buildFeatures(),
                  const SizedBox(height: 32),

                  // ── کارت فرم ──
                  _buildFormCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── لوگوی M با گرادیان ──
  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo.png',
      width: 80,
      height: 80,
      fit: BoxFit.contain,
    );
  }

  // ── چیپ‌های ویژگی ──
  Widget _buildFeatures() {
    final items = [
      (Icons.verified_user_outlined, 'قابل اعتماد'),
      (Icons.bolt_outlined, 'سریع'),
      (Icons.psychology_outlined, 'هوشمند'),
      (Icons.lock_outline_rounded, 'ساده'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((item) {
        return Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.$1, color: _primary, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              item.$2,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ── کارت فرم ──
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // نام کاربری
          const Text(
            'نام کاربری',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          _inputField(
            controller: _usernameController,
            hint: 'شماره موبایل',
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.number,
            onlyDigits: true,
          ),
          const SizedBox(height: 18),

          // رمز عبور
          const Text(
            'رمز عبور',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          _inputField(
            controller: _passwordController,
            hint: 'رمز عبور',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
          ),
          const SizedBox(height: 16),

          // مرا به خاطر بسپار + فراموشی رمز
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // فراموشی رمز
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'فراموشی رمز عبور',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // مرا به خاطر بسپار
              Row(
                children: [
                  Text(
                    'مرا به خاطر بسپار',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? false),
                      activeColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // دکمه ورود با گرادیان
          _buildLoginButton(),
          const SizedBox(height: 20),

          // ثبت نام سازمان جدید (با خطوط کناری)
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade200)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'ثبت نام سازمان جدید',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade200)),
            ],
          ),
          const SizedBox(height: 16),

          // نوار SSL
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_outlined, size: 15, color: _accent),
                const SizedBox(width: 6),
                Text(
                  'ارتباط شما با پروتکل SSL محافظت می‌شود',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── دکمه ورود ──
  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _login,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primaryLight, _primary],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'ورود به سیستم',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  // ── فیلد ورودی ──
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    bool onlyDigits = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: keyboardType,
      inputFormatters: onlyDigits
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 15, color: _ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        // آیکون سمت راست (در RTL، prefixIcon سمت راست می‌آید)
        prefixIcon: Icon(icon, color: _primary, size: 21),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey.shade400,
                  size: 21,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  void _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      Get.snackbar(
        'خطا',
        'لطفاً نام کاربری و رمز عبور را وارد کنید',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return;
    }
    setState(() => _isLoading = true);
    final result = await AuthService.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );
    setState(() => _isLoading = false);
    if (result['success']) {
      ApiClient.currentUserId = result['user']['id'];
      Get.off(() => MainShell(user: result['user']));
    } else {
      Get.snackbar(
        '❌ خطا',
        result['message'],
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }
}

// ── نقاش پس‌زمینه: خطوط مدار + نقاط ظریف ──
class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // نقاط ظریف
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final dots = [
      (Offset(w * 0.75, h * 0.10), 4.0, const Color(0x336D28D9)),
      (Offset(w * 0.85, h * 0.14), 3.0, const Color(0x3310B981)),
      (Offset(w * 0.15, h * 0.30), 3.5, const Color(0x336D28D9)),
      (Offset(w * 0.10, h * 0.45), 3.0, const Color(0x3322D3EE)),
      (Offset(w * 0.90, h * 0.50), 3.0, const Color(0x336D28D9)),
      (Offset(w * 0.20, h * 0.85), 4.0, const Color(0x3310B981)),
      (Offset(w * 0.80, h * 0.90), 3.0, const Color(0x336D28D9)),
    ];
    for (final d in dots) {
      dotPaint.color = d.$3;
      canvas.drawCircle(d.$1, d.$2, dotPaint);
    }

    // خطوط مدار ظریف بالا-راست
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x226D28D9);
    final path = Path()
      ..moveTo(w * 0.70, h * 0.08)
      ..lineTo(w * 0.80, h * 0.08)
      ..lineTo(w * 0.85, h * 0.13);
    canvas.drawPath(path, linePaint);

    // موج‌های پایین صفحه
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 0; i < 3; i++) {
      wavePaint.color = [
        const Color(0x226D28D9),
        const Color(0x2222D3EE),
        const Color(0x2210B981),
      ][i];
      final wave = Path()..moveTo(0, h * (0.93 + i * 0.02));
      wave.quadraticBezierTo(
        w * 0.5,
        h * (0.88 + i * 0.02),
        w,
        h * (0.95 + i * 0.02),
      );
      canvas.drawPath(wave, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
