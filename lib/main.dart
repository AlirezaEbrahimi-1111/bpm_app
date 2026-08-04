import 'dart:async';
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
  ApiClient.onSessionExpired = _handleSessionExpired;
  // اگر «مرا به خاطر بسپار» فعال بوده، مستقیم کاربر را وارد می‌کنیم
  final autoUser = await ApiClient.getAutoLoginUser();
  runApp(BpmApp(initialUser: autoUser));
}

// ════════════════════════════════════════════════════════
// وقتی سرور توکن ذخیره‌شده را نامعتبر/منقضی اعلام کند (مثلاً بعد از
// ورود خودکار با «مرا به خاطر بسپار»، وقتی توکن محلی هنوز هست ولی
// دیگر روی سرور معتبر نیست)، به‌جای این‌که صفحات مختلف بی‌صدا خالی یا
// خراب بمانند، کاربر را با یک پیغام روشن به صفحه‌ی ورود برمی‌گردانیم.
// ════════════════════════════════════════════════════════
bool _sessionExpiredHandled = false;

void _handleSessionExpired() {
  if (_sessionExpiredHandled) return;
  _sessionExpiredHandled = true;
  ApiClient.clearToken().then((_) {
    Get.offAll(() => const LoginPage());
    Get.snackbar(
      'نشست شما منقضی شده',
      'لطفاً دوباره وارد شوید',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange.shade100,
    );
  });
  Future.delayed(
    const Duration(seconds: 3),
    () => _sessionExpiredHandled = false,
  );
}

class BpmApp extends StatelessWidget {
  final Map<String, dynamic>? initialUser;
  const BpmApp({super.key, this.initialUser});

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
      home: initialUser != null
          ? MainShell(user: initialUser!)
          : const LoginPage(),
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
  final _passwordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  // 🔧 فرم سه‌مرحله‌ای مثل نسخه‌ی وب: ۱=شماره موبایل، ۲=رمز عبور، ۳=OTP
  int _currentStep = 1;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  // 🔧 اصلاح: به‌جای ۶ TextField جدا (که هرکدام autofillHints جدا
  // ثبت می‌کردند و باعث هنگ/ANR می‌شدند)، فقط یک فیلد واقعیِ نامرئی
  // داریم؛ ۶ خانه فقط نمایشی‌اند و از روی متن همین فیلد رسم می‌شوند.
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  int _resendSeconds = 0;
  Timer? _resendTimer;

  // رنگ‌های برند (هماهنگ با نسخه وب)
  static const _primary = Color(0xFF6D28D9); // بنفش اصلی
  static const _primaryLight = Color(0xFF8B5CF6); // بنفش روشن
  static const _accent = Color(0xFF10B981); // سبز برند
  static const _ink = Color(0xFF1A1A2E); // متن تیره

  bool get _isPhoneValid =>
      RegExp(r'^09[0-9]{9}$').hasMatch(_usernameController.text.trim());

  @override
  void initState() {
    super.initState();
    // 🔧 اصلاح: بعد از تکمیل ۱۱ رقم شماره موبایل معتبر، خودکار برود
    // مرحله‌ی بعد (رمز عبور) — دیگر نیازی به ضربه‌ی دستی روی «ادامه» نیست
    _usernameController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    if (!mounted) return;
    setState(() {}); // برای فعال/غیرفعال شدن دکمه‌ی «ادامه»
    if (_currentStep == 1 &&
        _usernameController.text.trim().length == 11 &&
        _isPhoneValid) {
      _goToStep2();
    }
  }

  void _goToStep2() {
    setState(() => _currentStep = 2);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _passwordFocusNode.requestFocus(),
    );
  }

  // بازگشت: از مرحله‌ی ۳ به ۲، یا از ۲ به ۱ — دقیقاً مثل وب
  void _goBack() {
    if (_currentStep == 3) {
      _resendTimer?.cancel();
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      setState(() => _currentStep = 1);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => FocusScope.of(context).unfocus(),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.removeListener(_onPhoneChanged);
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _resendTimer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

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
              // 🔧 اصلاح: وقتی کیبورد باز می‌شود باید بشود اسکرول کرد
              // وگرنه فیلد رمز عبور پشت کیبورد گم می‌شود. با فیزیک
              // پیش‌فرض، تا وقتی محتوا در صفحه جا می‌شود اسکرول غیرفعال
              // می‌ماند و فقط وقتی کیبورد جا را تنگ می‌کند فعال می‌شود.
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

  // ── لوگو ──
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
          if (_currentStep == 1)
            ..._buildStep1()
          else if (_currentStep == 2)
            ..._buildStep2()
          else
            ..._buildStep3(),
          const SizedBox(height: 20),

          if (_currentStep == 1) ...[
            // ثبت نام سازمان جدید (با خطوط کناری) — فقط مرحله‌ی اول، مثل وب
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
          ],

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

  // ── مرحله‌ی ۱: فقط شماره موبایل ──
  List<Widget> _buildStep1() {
    return [
      const Text(
        'شماره موبایل',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _ink),
      ),
      const SizedBox(height: 8),
      _inputField(
        controller: _usernameController,
        hint: 'شماره موبایل خود را وارد کنید',
        icon: Icons.person_outline_rounded,
        keyboardType: TextInputType.number,
        onlyDigits: true,
      ),
      const SizedBox(height: 20),

      // دکمه‌ی ادامه — تا شماره معتبر نباشد غیرفعال است
      GestureDetector(
        onTap: _isPhoneValid ? _goToStep2 : null,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isPhoneValid
                  ? const [_primaryLight, _primary]
                  : [Colors.grey.shade300, Colors.grey.shade300],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: _isPhoneValid
                ? [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: const Center(
            child: Text(
              'ادامه',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  // ── مرحله‌ی ۲: رمز عبور (+ لینک ورود با کد یکبارمصرف) ──
  List<Widget> _buildStep2() {
    return [
      _backButton(),
      const SizedBox(height: 14),

      const Text(
        'رمز عبور',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _ink),
      ),
      const SizedBox(height: 8),
      _inputField(
        controller: _passwordController,
        focusNode: _passwordFocusNode,
        hint: 'رمز عبور خود را وارد کنید',
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
            onPressed: _showForgotPasswordDialog,
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
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
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
      const SizedBox(height: 18),

      // خط جداکننده + ورود با کد یکبارمصرف — مثل وب
      Divider(color: Colors.grey.shade200),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: _isSendingOtp ? null : _sendOtp,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E0FB)),
            color: const Color(0xFFFBF9FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: _isSendingOtp
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primary,
                    ),
                  )
                : const Text(
                    'ورود با کد یکبارمصرف',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    ];
  }

  // ── مرحله‌ی ۳: ۶ خانه‌ی کد OTP + تایمر ──
  List<Widget> _buildStep3() {
    final phone = _usernameController.text.trim();
    return [
      _backButton(),
      const SizedBox(height: 14),

      // نمایش شماره‌ای که کد به آن ارسال شد
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'کد تأیید به $phone ارسال شد',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ),
      const SizedBox(height: 18),

      const Text(
        'کد ۶ رقمی را وارد کنید',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _ink),
      ),
      const SizedBox(height: 10),

      // ۶ خانه‌ی کد
      _buildOtpInput(),
      const SizedBox(height: 18),

      // دکمه ورود
      GestureDetector(
        onTap: _isVerifyingOtp ? null : _verifyOtp,
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
            child: _isVerifyingOtp
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'ورود',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
      const SizedBox(height: 16),

      // شمارش معکوس / ارسال مجدد
      Center(
        child: _resendSeconds > 0
            ? Text(
                'ارسال مجدد کد تا '
                '${(_resendSeconds ~/ 60).toString().padLeft(2, '0')}:'
                '${(_resendSeconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              )
            : TextButton(
                onPressed: _isSendingOtp ? null : _resendOtp,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'ارسال مجدد کد',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    ];
  }

  // ── ۶ خانه‌ی نمایشی OTP + یک فیلد واقعی نامرئی روی همه‌شان ──
  // 🔧 اصلاح: قبلاً ۶ TextField واقعی جدا داشتیم که هرکدام
  // autofillHints ثبت می‌کردند — همین باعث هنگ/ANR در برخی گوشی‌ها
  // می‌شد. حالا فقط یک TextField واقعی (نامرئی) وجود دارد که همه‌ی
  // تایپ/پیست/Autofill را می‌گیرد؛ Backspace هم رفتار طبیعی خودِ
  // TextField است، نیازی به دستکاری کلید نیست.
  Widget _buildOtpInput() {
    return AutofillGroup(
      child: SizedBox(
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _otpController,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.ltr,
                children: List.generate(6, _otpDisplayBox),
              ),
            ),
            Positioned.fill(
              child: TextField(
                controller: _otpController,
                focusNode: _otpFocusNode,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  setState(() {});
                  if (v.length == 6) _verifyOtp();
                },
                style: const TextStyle(color: Colors.transparent, fontSize: 1),
                cursorColor: Colors.transparent,
                decoration: const InputDecoration(
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── یک خانه‌ی نمایشیِ کد OTP (بدون FocusNode/Controller جدا) ──
  Widget _otpDisplayBox(int i) {
    final text = _otpController.text;
    final char = i < text.length ? text[i] : '';
    final isActive = i == text.length;
    return Container(
      width: 44,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: char.isNotEmpty ? Colors.white : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? _primary : Colors.grey.shade300,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _ink,
        ),
      ),
    );
  }

  // ── ارسال کد ──
  Future<void> _sendOtp() async {
    final phone = _usernameController.text.trim();
    if (!RegExp(r'^09[0-9]{9}$').hasMatch(phone)) {
      Get.snackbar(
        'خطا',
        'لطفاً شماره موبایل معتبر وارد کنید',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return;
    }
    setState(() => _isSendingOtp = true);
    final result = await AuthService.sendOtp(phone);
    setState(() => _isSendingOtp = false);
    if (result['success'] == true) {
      _otpController.clear();
      setState(() => _currentStep = 3);
      _startResendTimer();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _otpFocusNode.requestFocus(),
      );
    } else {
      Get.snackbar(
        'خطا',
        result['message']?.toString() ?? 'خطا در ارسال کد',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> _resendOtp() async {
    _otpController.clear();
    await _sendOtp();
  }

  // ── دکمه‌ی بازگشت بالای مرحله‌ی ۲ و ۳ ──
  Widget _backButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: _goBack,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: Colors.grey.shade600,
          backgroundColor: const Color(0xFFF3F4F6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
        label: const Text(
          'بازگشت',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  // ── تأیید کد و ورود ──
  Future<void> _verifyOtp() async {
    if (_isVerifyingOtp) return;
    final phone = _usernameController.text.trim();
    final code = _otpController.text;
    if (code.length != 6) {
      Get.snackbar(
        'خطا',
        'کد تأیید ۶ رقمی را کامل وارد کنید',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return;
    }
    setState(() => _isVerifyingOtp = true);
    final result = await AuthService.verifyOtp(phone, code);
    setState(() => _isVerifyingOtp = false);
    if (result['success'] == true) {
      final user = result['user'] as Map<String, dynamic>;
      ApiClient.currentUserId = user['id'];
      await ApiClient.saveRememberMe(_rememberMe);
      if (_rememberMe) {
        await ApiClient.saveCachedUser(user);
      }
      _resendTimer?.cancel();
      Get.off(() => MainShell(user: user));
    } else {
      Get.snackbar(
        '❌ خطا',
        result['message']?.toString() ?? 'کد تأیید اشتباه است',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  // 🔧 اصلاح ۲: پیغام راهنمای فراموشی رمز عبور
  void _showForgotPasswordDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: _primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'بازیابی رمز عبور',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'برای بازیابی رمز عبور با پشتیبانی یا مدیر سازمان خود تماس بگیرید.',
                style: TextStyle(fontSize: 14, color: _ink, height: 1.6),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'متوجه شدم',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    FocusNode? focusNode,
    bool isPassword = false,
    TextInputType? keyboardType,
    bool onlyDigits = false,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
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
      final user = result['user'] as Map<String, dynamic>;
      ApiClient.currentUserId = user['id'];

      // 🔧 اصلاح ۳: ذخیره وضعیت «مرا به خاطر بسپار»
      // اگر فعال باشد، دفعه‌ی بعد بدون نیاز به ورود مجدد وارد می‌شود
      await ApiClient.saveRememberMe(_rememberMe);
      if (_rememberMe) {
        await ApiClient.saveCachedUser(user);
      }

      Get.off(() => MainShell(user: user));
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
