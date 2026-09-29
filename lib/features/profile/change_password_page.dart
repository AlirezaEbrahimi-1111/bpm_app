import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';

/// صفحه‌ی «تغییر رمز عبور» — طبق طرح ارسالی (روشن + تاریک)
///
/// متصل به POST /api/auth/change-password.php (فیلدها:
/// current_password، new_password). چک‌لیستِ الزامات دقیقاً هم‌راستا با
/// Auth::validatePassword در بک‌اند است: حداقل ۸ کاراکتر + حداقل یک
/// حرف + حداقل یک عدد (نه شرطِ حرف بزرگ/کوچکِ جدا یا نماد).
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _focusNodes = <TextEditingController, FocusNode>{};
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  bool get _hasMinLength => _newController.text.length >= 8;
  bool get _hasLetter => RegExp(r'[A-Za-z]').hasMatch(_newController.text);
  bool get _hasDigit => RegExp(r'[0-9]').hasMatch(_newController.text);

  int get _strength =>
      [_hasMinLength, _hasLetter, _hasDigit].where((v) => v).length;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  // 🔧 طبق درخواست: دکمه دیگر غیرفعال نیست — اگر اطلاعات ناقص باشد،
  // به‌جای بی‌اثر بودن، پیام مشخص می‌کند چه چیزی کم است
  String? get _validationMessage {
    if (_currentController.text.isEmpty) return 'لطفاً رمز فعلی را وارد کنید';
    if (_newController.text.isEmpty) return 'لطفاً رمز جدید را وارد کنید';
    if (!_hasMinLength || !_hasLetter || !_hasDigit) {
      return 'رمز جدید باید حداقل ۸ کاراکتر و شامل حرف و عدد باشد';
    }
    if (_confirmController.text.isEmpty)
      return 'لطفاً تکرار رمز جدید را وارد کنید';
    if (_newController.text != _confirmController.text)
      return 'تکرار رمز جدید مطابقت ندارد';
    return null;
  }

  Future<void> _save() async {
    final validation = _validationMessage;
    if (validation != null) {
      AppSnack.error('خطا', validation);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final res = await ApiClient.dio.post(
        '/api/auth/change-password.php',
        data: {
          'current_password': _currentController.text,
          'new_password': _newController.text,
        },
      );
      final data = ApiClient.parseResponse(res.data);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (data['success'] == true) {
        Get.back();
        AppSnack.success(
          '✅ موفق',
          (data['message'] ?? 'رمز عبور با موفقیت تغییر کرد').toString(),
        );
      } else {
        AppSnack.error(
          'خطا',
          (data['message'] ?? 'خطا در تغییر رمز عبور').toString(),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bgPage,
      appBar: AppBar(
        backgroundColor: c.bgPage,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textStrong),
        title: Text(
          'تغییر رمز عبور',
          style: TextStyle(
            color: c.textStrong,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: Transform.rotate(
            angle: math.pi, // 🔧 طبق درخواست: ۱۸۰ درجه چرخید
            child: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── بنر راهنما ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.borderSoft),
              ),
              child: Row(
                children: [
                  // 🔧 طبق درخواست: آیکن سمتِ راست، متن بلافاصله بعدش
                  // در همان خط (نه در دو سرِ مخالفِ کادر)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [c.primaryLight, c.primary],
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'برای امنیت بیشتر، رمز جدید باید قوی باشد',
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _passwordField(
              c: c,
              label: 'رمز فعلی',
              controller: _currentController,
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            _passwordField(
              c: c,
              label: 'رمز جدید',
              controller: _newController,
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _strengthBar(c),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'رمز پیشنهادی: حداقل ۸ کاراکتر، شامل عدد و حرف',
                style: TextStyle(fontSize: 11.5, color: c.textMuted),
              ),
            ),
            const SizedBox(height: 14),

            _passwordField(
              c: c,
              label: 'تکرار رمز جدید',
              controller: _confirmController,
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // ── چک‌لیست الزامات ──
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.borderSoft),
              ),
              child: Column(
                children: [
                  _ruleRow(c, 'حداقل ۸ کاراکتر', _hasMinLength),
                  _ruleRow(c, 'شامل حرف', _hasLetter),
                  _ruleRow(c, 'شامل عدد', _hasDigit, isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  disabledBackgroundColor: c.primary.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : const Text(
                        'ذخیره رمز جدید',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'انصراف',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField({
    required AppColors c,
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required ValueChanged<String> onChanged,
  }) {
    // 🔧 ضربه روی هر جای کادر (قفل، برچسب، حاشیه) فیلد را فوکوس می‌کند،
    // نه فقط روی خودِ ناحیه‌ی کوچکِ متن
    final focusNode = _focusNodes.putIfAbsent(controller, FocusNode.new);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focusNode.requestFocus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.borderSoft),
        ),
        // 🔧 طبق درخواست: قفل، برچسب و چشم (و خودِ فیلد) همه در «یک ردیف»
        // و وسط‌چینِ عمودیِ کادر — دیگر برچسب بالا و فیلد پایینِ آن نیست
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 20, color: c.textMuted),
            const SizedBox(width: 10),
            // 🔧 طبق درخواست: برچسب (رمز فعلی/جدید/تکرار) حالا placeholder
            // است — با تایپ‌کردن ناپدید می‌شود — و متن/placeholder وسط‌چین است
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscure,
                onChanged: onChanged,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textStrong,
                ),
                decoration: InputDecoration(
                  hintText: label,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: c.textMuted,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 19,
                color: c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _strengthBar(AppColors c) {
    final colors = [c.danger, c.warning, c.success];
    final activeColor = _strength == 0 ? c.borderSoft : colors[_strength - 1];
    return Row(
      children: List.generate(3, (i) {
        final filled = i < _strength;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: i == 2 ? 0 : 6),
            height: 5,
            decoration: BoxDecoration(
              color: filled ? activeColor : c.borderSoft,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  Widget _ruleRow(
    AppColors c,
    String label,
    bool satisfied, {
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: c.borderSoft)),
      ),
      child: Row(
        children: [
          Icon(
            satisfied
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 19,
            color: satisfied ? c.success : c.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: satisfied ? c.textStrong : c.textMuted,
              fontWeight: satisfied ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
