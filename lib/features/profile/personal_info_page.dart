import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';

/// صفحه‌ی «اطلاعات شخصی» — طبق طرح ارسالی (روشن + تاریک)
///
/// متصل به:
/// - PUT  /api/auth/profile.php          (فیلدها: first_name، last_name)
/// - POST /api/profile/upload-avatar.php (multipart، فیلد: avatar)
///
/// 🔧 طبق درخواست، فیلد ایمیل از این صفحه حذف شده (نه نمایش داده
/// می‌شود و نه در درخواستِ ذخیره ارسال می‌شود؛ endpoint هم چون email
/// اختیاری است، بدون آن مشکلی ندارد).
///
/// 🔧 شماره‌ی تماس عمداً غیرقابل‌ویرایش نگه داشته شده چون endpoint فعلیِ
/// ویرایشِ پروفایل (مطابق نسخه‌ی دسکتاپ) شماره را نمی‌پذیرد — تغییرِ
/// شماره معادلِ تغییرِ نام‌کاربری/ورود است و باید جداگانه بررسی شود.
class PersonalInfoPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const PersonalInfoPage({super.key, required this.user});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  late final TextEditingController _nameController;
  final _nameFocus = FocusNode();
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _avatarPath;

  String _roleLabel(String? role, String? section) {
    if (section == 'management' && role == 'supervisor') return 'مدیر سازمان';
    return switch (role) {
      'supervisor' => 'سرپرست',
      'management' => 'مدیر',
      'manager' => 'مدیر',
      'employee' => 'کارمند',
      'admin' => 'ادمین',
      _ => 'کاربر',
    };
  }

  @override
  void initState() {
    super.initState();
    final firstName = (widget.user['first_name'] ?? '').toString();
    final lastName = (widget.user['last_name'] ?? '').toString();
    _nameController = TextEditingController(
      text: '$firstName $lastName'.trim(),
    );
    _avatarPath = widget.user['avatar_path']?.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isUploadingAvatar = true);
      final formData = dio.FormData.fromMap({
        'avatar': dio.MultipartFile.fromBytes(file.bytes!, filename: file.name),
      });
      final res = await ApiClient.dio.post(
        '/api/profile/upload-avatar.php',
        data: formData,
      );
      final data = ApiClient.parseResponse(res.data);
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);

      if (data['success'] == true) {
        final newPath = data['avatar_path']?.toString();
        setState(() => _avatarPath = newPath);
        widget.user['avatar_path'] = newPath;
        await ApiClient.saveCachedUser(widget.user);
        AppSnack.success('✅ موفق', 'تصویر پروفایل بروزرسانی شد');
      } else {
        AppSnack.error(
          'خطا',
          (data['message'] ?? 'خطا در آپلود تصویر').toString(),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  Future<void> _saveChanges() async {
    final fullName = _nameController.text.trim();
    if (fullName.isEmpty) {
      AppSnack.error('خطا', 'نام و نام خانوادگی نمی‌تواند خالی باشد');
      return;
    }
    // 🔧 فیلد «نام و نام خانوادگی» در طرح یک فیلد واحد است ولی API دو
    // فیلدِ جدا (first_name/last_name) می‌خواهد — با اولین فاصله تفکیک
    // می‌شود (اولین بخش = نام، باقی = نام‌خانوادگی)
    final parts = fullName.split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    if (lastName.isEmpty) {
      AppSnack.error('خطا', 'لطفاً نام و نام خانوادگی را با فاصله وارد کنید');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final res = await ApiClient.dio.put(
        '/api/auth/profile.php',
        data: {'first_name': firstName, 'last_name': lastName},
      );
      final data = ApiClient.parseResponse(res.data);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (data['success'] == true) {
        widget.user['first_name'] = firstName;
        widget.user['last_name'] = lastName;
        await ApiClient.saveCachedUser(widget.user);
        Get.back();
        AppSnack.success(
          '✅ موفق',
          (data['message'] ?? 'اطلاعات بروزرسانی شد').toString(),
        );
      } else {
        AppSnack.error(
          'خطا',
          (data['message'] ?? 'خطا در بروزرسانی اطلاعات').toString(),
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
    final firstName = (widget.user['first_name'] ?? '').toString();
    final roleLabel = _roleLabel(
      widget.user['role'],
      widget.user['activity_section'],
    );
    final sectionLabel = switch ((widget.user['activity_section'] ?? '')
        .toString()) {
      'management' => 'مدیریت',
      'sales' => 'فروش',
      'purchase' => 'خرید',
      'warehouse' => 'انبار',
      final s => s.isEmpty ? '—' : s,
    };
    final phone = (widget.user['phone'] ?? '').toString();

    return Scaffold(
      backgroundColor: c.bgPage,
      appBar: AppBar(
        backgroundColor: c.bgPage,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textStrong),
        title: Text(
          'اطلاعات شخصی',
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
            // ── کارت آواتار + نام ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.borderSoft),
              ),
              // 🔧 طبق عکسِ ارسالی: عکس سمتِ راست، جلوش (سمتِ چپ) نام و
              // دکمه‌ی تغییرِ تصویر پایین‌چین — با end هر دو ته‌ی هم
              // تراز می‌شوند؛ border-radius عکس هم خیلی کم (نه دایره‌ای)
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        36,
                      ), // گرد کامل (عرض ۷۲ ÷ ۲)
                      gradient: (_avatarPath == null || _avatarPath!.isEmpty)
                          ? LinearGradient(colors: [c.primaryLight, c.primary])
                          : null,
                      color: c.borderSoft,
                      image: (_avatarPath != null && _avatarPath!.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(
                                '${ApiClient.baseUrl}/$_avatarPath',
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (_avatarPath == null || _avatarPath!.isEmpty)
                        ? Center(
                            child: Text(
                              firstName.isNotEmpty ? firstName[0] : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // 🔧 طبق درخواست: نام کنارِ عکس (بالا) و دکمه‌ی «تغییر تصویر»
                  // جدا، در گوشه‌ی پایین-چپِ همین کادر و با border-radius زیاد
                  Expanded(
                    child: SizedBox(
                      height: 72,
                      child: Align(
                        alignment: AlignmentDirectional
                            .centerStart, // وسطِ ارتفاعِ عکس
                        child: Text(
                          _nameController.text.isEmpty
                              ? 'کاربر'
                              : _nameController.text,
                          style: TextStyle(
                            color: c.textStrong,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // فاصله‌ی دکمه از چپ/پایینِ کادر: کادر ۲۰ پیکسل padding دارد؛ با
                  // این جابه‌جایی ۱۰ پیکسل به چپ و ۸ پیکسل به پایین می‌رود (فاصله
                  // ~۱۰ چپ و ~۱۲ پایین). عددها را کم/زیاد کنید تا تنظیم شود.
                  Transform.translate(
                    offset: const Offset(-10, 8),
                    child: OutlinedButton.icon(
                      onPressed: _isUploadingAvatar
                          ? null
                          : _pickAndUploadAvatar,
                      icon: _isUploadingAvatar
                          ? SizedBox(
                              width: 11,
                              height: 11,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.primary,
                              ),
                            )
                          : Icon(
                              Icons.edit_outlined,
                              size: 12,
                              color: c.primary,
                            ),
                      label: Text(
                        'تغییر تصویر',
                        style: TextStyle(color: c.primary, fontSize: 10.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: c.primary.withValues(alpha: 0.5),
                        ),
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.standard,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _sectionTitle(c, 'مشخصات فردی'),
            _editableRow(
              c: c,
              icon: Icons.person_outline_rounded,
              label: 'نام و نام خانوادگی',
              controller: _nameController,
              focusNode: _nameFocus,
              keyboardType: TextInputType.name,
            ),
            // 🔧 شماره تماس از سمت این endpoint قابل ویرایش نیست
            _readonlyRow(
              c: c,
              icon: Icons.phone_outlined,
              label: 'شماره تماس',
              value: phone.isEmpty ? '—' : phone,
            ),
            // 🔧 سمت شغلی و نام سازمان توسط مدیر سیستم تعیین می‌شوند،
            // بنابراین از سمت کاربر قابل ویرایش نیستند (بدون آیکون مداد).
            _readonlyRow(
              c: c,
              icon: Icons.work_outline_rounded,
              label: 'سمت شغلی',
              value: roleLabel,
            ),
            _readonlyRow(
              c: c,
              icon: Icons.apartment_rounded,
              label: 'نام سازمان',
              value: 'آوای شرق ملک',
            ),
            _readonlyRow(
              c: c,
              icon: Icons.business_outlined,
              label: 'واحد',
              value: sectionLabel,
              isLast: true,
            ),

            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
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
                        'ذخیره تغییرات',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(AppColors c, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: c.textStrong,
        ),
      ),
    ),
  );

  Widget _editableRow({
    required AppColors c,
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required TextInputType keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.borderSoft),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, color: c.textMuted),
                ),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textStrong,
                  ),
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => FocusScope.of(context).requestFocus(focusNode),
            child: Icon(Icons.edit_outlined, size: 18, color: c.primary),
          ),
        ],
      ),
    );
  }

  Widget _readonlyRow({
    required AppColors c,
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.borderSoft),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, color: c.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textStrong,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: c.textMuted.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}
