import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/notification_bar_preference.dart';
import '../../core/theme/font_size_preference.dart';
import '../../core/utils/persian_number.dart';
import '../../core/widgets/app_switch.dart';
import '../shell/widgets/about_sheet.dart';

/// صفحه‌ی «تنظیمات» — طبق طرح ارسالی (روشن + تاریک).
///
/// 🔧 هر ردیف به یک قابلیتِ واقعاً موجود در اپ وصل است: تمِ تاریک،
/// اندازه‌ی فونت (با MediaQuery.textScaler در main.dart روی کلِ اپ اعمال
/// می‌شود)، نمایش نوار اعلان، درباره ما. هیچ سوییچی نمایشی/بی‌اثر نیست.
///
/// 🔧 این ویجت Scaffold/AppBarِ خودش را ندارد — چون یکی از تب‌هایِ خودِ
/// پوسته‌ی اصلی است (هدر/نوارِ پایین مشترک با بقیه‌ی تب‌ها). دراور هم
/// مستقیم به همین تب سوییچ می‌کند (onTabSelected)، نه با push.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      color: c.bgPage,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle(c, 'عمومی'),
              _card(
                c,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: ThemeController.isDarkNotifier,
                    builder: (context, isDark, _) => _row(
                      c,
                      icon: isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      label: 'تم ظاهری',
                      value: isDark ? 'تاریک' : 'روشن',
                      onTap: () => _showThemeSheet(context, c),
                    ),
                  ),
                  ValueListenableBuilder<AppFontSize>(
                    valueListenable: FontSizePreference.sizeNotifier,
                    builder: (context, fontSize, _) => _row(
                      c,
                      icon: Icons.text_fields_rounded,
                      label: 'اندازه فونت',
                      value: fontSize.label,
                      onTap: () => _showFontSizeSheet(context, c),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable:
                        NotificationBarPreference.isEnabledNotifier,
                    builder: (context, enabled, _) => _switchRow(
                      c,
                      icon: Icons.notifications_active_outlined,
                      label: 'نمایش نوار اعلان',
                      value: enabled,
                      onChanged: NotificationBarPreference.setEnabled,
                      isLast: true,
                    ),
                  ),
                ],
              ),
              _sectionTitle(c, 'درباره نرم‌افزار'),
              _card(
                c,
                children: [
                  _row(
                    c,
                    icon: Icons.info_outline_rounded,
                    label: 'درباره ما',
                    value: '',
                    onTap: () => showAboutSheet(context),
                  ),
                  // 🔧 رفعِ باگ: قبلاً یک عددِ هاردکد («۴.۰») نمایش داده
                  // می‌شد که با pubspec.yaml هم‌خوان نبود و هیچ‌وقت خودکار
                  // به‌روز نمی‌شد — حالا مستقیم از پکیجِ نصب‌شده خونده می‌شه
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      // 🔧 طبق درخواست: فقط شماره‌ی نسخه («۱.۰.۱») نمایش
                      // داده می‌شود، بدونِ پسوندِ «+buildNumber» که برایِ
                      // کاربرِ نهایی گیج‌کننده بود
                      final value = info == null
                          ? ''
                          : toPersianDigits(info.version);
                      return _row(
                        c,
                        icon: Icons.numbers_rounded,
                        label: 'نسخه نرم‌افزار',
                        value: value,
                        enabled: false,
                        isLast: true,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(AppColors c, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
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

  Widget _card(AppColors c, {required List<Widget> children}) => Container(
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.borderSoft),
    ),
    child: Column(children: children),
  );

  Widget _row(
    AppColors c, {
    required IconData icon,
    required String label,
    required String value,
    bool enabled = true,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: c.borderSoft)),
      ),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.textMuted),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textStrong,
              ),
            ),
            const Spacer(),
            if (value.isNotEmpty) ...[
              Text(value, style: TextStyle(fontSize: 13, color: c.textMuted)),
              const SizedBox(width: 8),
            ],
            if (enabled && onTap != null)
              Icon(Icons.chevron_right_rounded, size: 20, color: c.textMuted),
          ],
        ),
      ),
    );
    if (!enabled || onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }

  Widget _switchRow(
    AppColors c, {
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: c.borderSoft)),
      ),
      child: Opacity(
        opacity: onChanged == null ? 0.5 : 1,
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textStrong,
                ),
              ),
            ),
            AppSwitch(
              value: value,
              onChanged: onChanged,
              activeColor: c.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSheet(BuildContext context, AppColors c) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'تم ظاهری',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: c.textStrong,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.light_mode_rounded, color: c.textStrong),
                title: Text('روشن', style: TextStyle(color: c.textStrong)),
                trailing: !ThemeController.isDark
                    ? Icon(Icons.check_rounded, color: c.primary)
                    : null,
                onTap: () async {
                  await ThemeController.setDark(false);
                  Get.back();
                },
              ),
              ListTile(
                leading: Icon(Icons.dark_mode_rounded, color: c.textStrong),
                title: Text('تاریک', style: TextStyle(color: c.textStrong)),
                trailing: ThemeController.isDark
                    ? Icon(Icons.check_rounded, color: c.primary)
                    : null,
                onTap: () async {
                  await ThemeController.setDark(true);
                  Get.back();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _fontSizeIcons = {
    AppFontSize.small: Icons.text_decrease_rounded,
    AppFontSize.medium: Icons.text_fields_rounded,
    AppFontSize.large: Icons.text_increase_rounded,
  };

  void _showFontSizeSheet(BuildContext context, AppColors c) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'اندازه فونت',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: c.textStrong,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...AppFontSize.values.map(
                (size) => ListTile(
                  leading: Icon(_fontSizeIcons[size], color: c.textStrong),
                  title: Text(
                    size.label,
                    style: TextStyle(color: c.textStrong),
                  ),
                  trailing: FontSizePreference.sizeNotifier.value == size
                      ? Icon(Icons.check_rounded, color: c.primary)
                      : null,
                  onTap: () async {
                    await FontSizePreference.set(size);
                    Get.back();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
