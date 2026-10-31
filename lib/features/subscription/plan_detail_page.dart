import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_number.dart';
import '../../core/widgets/app_snack.dart';
import '../shell/widgets/app_bottom_nav.dart';
import 'plan_feature_list.dart';
import 'payment_webview_page.dart';
import '../../core/navigation/app_nav.dart';

enum SubscriptionPlanType { gold, silver }

/// قیمت‌هایِ واقعیِ پلن‌ها — طبقِ لیستِ ارسالی. این‌جا فقط برایِ *نمایش*
/// هاردکد است؛ سرور (`includes/plan-pricing.php` در بک‌اند) هم دقیقاً
/// همین جدول را مستقل دارد و قیمتِ واقعی را خودش حساب می‌کند — هیچ‌وقت
/// عددی که از کلاینت می‌آید پذیرفته نمی‌شود.
class PlanPricing {
  PlanPricing._();

  /// تعدادِ کاربر → مدت (ماه) → قیمت (تومان)
  static const Map<int, Map<int, int>> gold = {
    5: {1: 3700000, 6: 15000000, 12: 24000000},
    10: {1: 5600000, 6: 24000000, 12: 38000000},
    20: {1: 10000000, 6: 39000000, 12: 62000000},
    40: {1: 16500000, 6: 66000000, 12: 105000000},
  };

  /// مدت (ماه) → قیمت (تومان) — پلنِ نقره‌ای تعدادِ کاربر ندارد
  static const Map<int, int> silver = {1: 200000, 6: 1000000, 12: 2100000};
}

/// صفحه‌ی جزئیات/خریدِ یک پلن — طبقِ طرحِ ارسالی (روشن + تاریک). فقط پلنِ
/// طلایی انتخابِ «تعداد کاربر» دارد؛ نقره‌ای قیمتِ ثابت بر اساسِ مدت دارد.
class PlanDetailPage extends StatefulWidget {
  final SubscriptionPlanType plan;
  const PlanDetailPage({super.key, required this.plan});

  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  int _users = 10;
  int _months = 12;
  bool _isPaying = false;

  bool get _isGold => widget.plan == SubscriptionPlanType.gold;

  int get _price => _isGold
      ? PlanPricing.gold[_users]![_months]!
      : PlanPricing.silver[_months]!;

  int _monthlyRate(int users) =>
      _isGold ? PlanPricing.gold[users]![1]! : PlanPricing.silver[1]!;

  int _fullPrice(int months) => _monthlyRate(_users) * months;

  int _discountPercent(int months) {
    if (months == 1) return 0;
    final full = _fullPrice(months);
    final actual = _isGold
        ? PlanPricing.gold[_users]![months]!
        : PlanPricing.silver[months]!;
    if (full <= actual) return 0;
    return (100 - (actual * 100 / full)).round();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _isGold ? const Color(0xFFF5B94D) : c.primary;
    final fullPrice = _fullPrice(_months);
    final hasDiscount = fullPrice > _price;

    return AppShellOverlays(
      child: Scaffold(
        backgroundColor: c.bgPage,
        appBar: AppBar(
          backgroundColor: c.bgPage,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: c.textStrong),
          title: Text(
            _isGold ? 'پلن طلایی (سازمانی)' : 'پلن نقره‌ای (تیمی)',
            style: TextStyle(
              color: c.textStrong,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          leading: IconButton(
            icon: Transform.rotate(
              angle: math.pi,
              child: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
            ),
            onPressed: () => AppNav.back(),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.share_rounded, color: c.textStrong, size: 20),
              onPressed: () => AppSnack.info(
                'به‌زودی',
                'اشتراک‌گذاری پلن هنوز فعال نشده است',
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _headerCard(c, isDark, accent),
                  // 🔧 طبق درخواست: «تعداد کاربران» و «مدت زمان اشتراک» دوباره
                  // جدا از هم، هرکدام در کارتِ مستقلِ خودش
                  if (_isGold) ...[
                    const SizedBox(height: 8),
                    _cardSection(
                      c,
                      title: 'تعداد کاربران',
                      icon: Icons.groups_rounded,
                      child: _userCountRow(c),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _cardSection(
                    c,
                    title: 'مدت زمان اشتراک',
                    icon: Icons.calendar_month_rounded,
                    child: _durationRow(c, accent),
                  ),
                  const SizedBox(height: 8),
                  _cardSection(
                    c,
                    title: 'امکانات و قابلیت‌ها',
                    icon: Icons.check_circle_outline_rounded,
                    child: _featuresCard(c),
                  ),
                ],
              ),
            ),
            _bottomBar(c, accent, fullPrice, hasDiscount),
          ],
        ),
        // 🔧 طبق درخواست: نوارِ ناوبرییِ پایین در همه‌ی صفحاتِ اپ — چون این صفحه با Get.to باز می‌شود، Scaffoldِ پوسته‌ی اصلی را نمی‌بیند
        // 🔧 طبق درخواست: دکمهِ شناورِ افزودنِ کار هم مثلِ پوستهِ اصلی
        floatingActionButton: const AppCreateTaskFab(),
        floatingActionButtonLocation: const LoweredDockedFabLocation(),
        // محتوا زیرِ نوار هم ادامه دارد تا محوشدنِ دورِ نوار دیده شود
        extendBody: true,
        bottomNavigationBar: const AppBottomNav(),
      ),
    );
  }

  // ── کارتِ بالا ──
  Widget _headerCard(AppColors c, bool isDark, Color accent) {
    final glowAlpha = isDark ? 0.32 : 0.14;
    final borderAlpha = isDark ? 0.55 : 0.32;
    // 🔧 طبق درخواست: در تمِ تاریک، سایه/کادرِ دورِ این کارت بنفش باشد
    // (نه رنگِ طلایی/نارنجیِ پلن) — رنگِ متن (زیرنویس و...) همچنان
    // رنگِ خودِ پلن (accent) باقی می‌ماند
    final glowColor = isDark ? c.primary : accent;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: glowColor.withValues(alpha: borderAlpha),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: glowAlpha),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isGold ? 'پلن طلایی' : 'پلن نقره‌ای',
                  style: TextStyle(
                    color: c.textStrong,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isGold
                      ? 'مدیریت فرآیندهای کسب‌وکار'
                      : 'همکاری و هماهنگی تیمی',
                  style: TextStyle(
                    color: c.textStrong,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isGold
                      ? 'کامل‌ترین سطح دسترسی مدیریتی، نظارتی و سازمانی'
                      : 'دسترسی مشترک تیم به برنامه و کارها',
                  style: TextStyle(color: accent, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 38,
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.asset(
                _isGold
                    ? 'assets/images/subscription/plan_gold.webp'
                    : 'assets/images/subscription/plan_silver.webp',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── کارتِ مستقل برایِ هر بخش (عنوان + محتوا) ──
  Widget _cardSection(
    AppColors c, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(c, title, icon),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _sectionTitle(AppColors c, String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 16, color: c.textMuted),
      const SizedBox(width: 6),
      Text(
        title,
        style: TextStyle(
          color: c.textStrong,
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );

  // ── ردیفِ تعدادِ کاربر (فقط طلایی) ──
  Widget _userCountRow(AppColors c) {
    const counts = [5, 10, 20, 40];
    return Row(
      children: counts.map((n) {
        final selected = n == _users;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: n == 40 ? 0 : 6),
            child: GestureDetector(
              onTap: () => setState(() => _users = n),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? c.primary : c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? c.primary : c.borderSoft,
                  ),
                ),
                child: Text(
                  toPersianDigits('$n کاربر'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : c.textStrong,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── ردیفِ مدتِ اشتراک — هر سه کارت دقیقاً یک‌سوم عرض، و یک قدِ ثابت
  // (بدونِ توجه به محتوایِ داخلشون) ──
  static const _durationCardHeight = 94.0;
  static const _durationBadgeSlot = 14.0;
  static const _durationBadgeHeight = 20.0;

  Widget _durationRow(AppColors c, Color accent) {
    final options = [
      (months: 1, label: '۱ ماهه'),
      (months: 6, label: '۶ ماهه'),
      (months: 12, label: '۱۲ ماهه / سالانه'),
    ];
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _durationCard(c, accent, options[i])),
        ],
      ],
    );
  }

  Widget _durationCard(
    AppColors c,
    Color accent,
    ({int months, String label}) o,
  ) {
    final selected = o.months == _months;
    final pct = _discountPercent(o.months);
    final isYearly = o.months == 12;
    // 🔧 طبق درخواست: در تمِ تاریک، کادرِ انتخاب‌شده‌یِ گزینه‌یِ سالانه هم
    // بنفش باشد، نه طلایی/نارنجی
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final yearlyBorderColor = isDark ? c.primary : const Color(0xFFF5B94D);
    // 🔧 رفعِ باگِ «کادرها هم‌اندازه نیستند / کلا مخفی می‌شوند»: این‌بار
    // به‌جایِ تکیه بر اندازه‌گیریِ خودکار (IntrinsicHeight/margin)، یک
    // SizedBox با ارتفاعِ کاملاً ثابت می‌گذاریم — یعنی صرفِ‌نظر از اینکه
    // محتوا (بج/تخفیف) باشد یا نه، قدِ کادر همیشه دقیقاً یکی است
    return GestureDetector(
      onTap: () => setState(() => _months = o.months),
      child: SizedBox(
        height: _durationCardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          // 🔧 طبق درخواست: عرضِ بج دقیقاً هم‌اندازه‌ی متنِ داخلش باشد —
          // چون left:0/right:0 قبلی، بج را تا عرضِ کلِ کارت می‌کشید. حالا
          // بج بدونِ left/right فقط با alignment وسط‌چین می‌شود و به
          // اندازه‌ی محتوایِ خودش (شرینک‌رپ) باقی می‌ماند
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: _durationBadgeSlot,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? (isYearly ? yearlyBorderColor : c.primary)
                        : c.borderSoft,
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      toPersianDigits(o.label),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: c.textStrong,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      toPersianDigits(
                        groupThousands(
                          (_isGold
                                  ? PlanPricing.gold[_users]![o.months]!
                                  : PlanPricing.silver[o.months]!)
                              .toString(),
                        ),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: selected ? accent : c.textStrong,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تومان',
                      style: TextStyle(
                        fontSize: 10,
                        color: c.textMuted,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isYearly)
              // 🔧 طبق درخواست: وسطِ بج دقیقاً روی لبه‌ی کارت بیفتد — چون
              // لبه‌ی کارت از y=_durationBadgeSlot شروع می‌شود، بج را
              // نصفِ ارتفاعِ خودش بالاتر می‌بریم تا مرکزش دقیقاً همان‌جا
              // باشد
              Positioned(
                top: _durationBadgeSlot - _durationBadgeHeight / 2,
                child: Container(
                  height: _durationBadgeHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // 🔧 طبق درخواست: در تمِ تاریک، بجِ «محبوب‌ترین» هم بنفش
                    color: isDark ? c.primary : const Color(0xFFF5B94D),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 11, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        'محبوب‌ترین',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (pct > 0)
              Positioned(
                top: _durationBadgeSlot - _durationBadgeHeight / 2,
                child: Container(
                  height: _durationBadgeHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // 🔧 طبق درخواست: در تمِ تاریک، بجِ «تخفیف» هم بنفش
                    color: isDark ? c.primary : c.success,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    toPersianDigits('٪$pct تخفیف'),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── لیستِ ویژگی‌ها ──
  Widget _featuresCard(AppColors c) {
    final features = _isGold ? goldPlanFeatures : silverPlanFeatures;
    return Column(
      children: features
          .map(
            (f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(f.$1, size: 17, color: c.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.$2,
                      style: TextStyle(fontSize: 12.5, color: c.textStrong),
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, size: 17, color: c.success),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // ── شروعِ پرداخت — زرین‌پال داخلِ WebView ──
  Future<void> _startPayment() async {
    if (_isPaying) return;
    setState(() => _isPaying = true);
    try {
      final res = await ApiClient.dio.post(
        '/api/payment/org-pay.php',
        data: {
          'plan': _isGold ? 'gold' : 'silver',
          'months': _months,
          if (_isGold) 'plan_users': _users,
        },
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] != true) {
        if (mounted) {
          AppSnack.error('خطا', data['message'] ?? 'خطا در اتصال به درگاه');
        }
        return;
      }

      final paymentUrl = data['payment_url']?.toString();
      if (paymentUrl == null || paymentUrl.isEmpty) {
        if (mounted) AppSnack.error('خطا', 'آدرس درگاه دریافت نشد');
        return;
      }

      final result = await Get.to<PaymentResult>(
        () => PaymentWebviewPage(paymentUrl: paymentUrl),
      );
      if (!mounted) return;

      switch (result) {
        case PaymentResult.success:
        case PaymentResult.already:
          await _refreshPlanAfterPayment();
          AppSnack.success('✅ پرداخت موفق', 'پلن سازمان شما به‌روزرسانی شد');
          AppNav.back();
          break;
        case PaymentResult.cancel:
          AppSnack.info('لغو شد', 'پرداخت لغو شد');
          break;
        case PaymentResult.failed:
        case PaymentResult.error:
        case PaymentResult.notfound:
          AppSnack.error('خطا', 'پرداخت ناموفق بود؛ مبلغی کسر نشده است');
          break;
        case null:
          break;
      }
    } catch (e) {
      if (mounted) AppSnack.error('خطا', 'خطا در اتصال به سرور');
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  // 🔧 بعدِ پرداختِ موفق، پلنِ کاربر را دوباره از سرور می‌خوانیم تا
  // PlanAccess (و بقیه‌ی اپ) بلافاصله پلنِ جدید را ببیند، بدونِ نیاز به
  // خروج/ورودِ مجدد
  Future<void> _refreshPlanAfterPayment() async {
    try {
      final res = await ApiClient.dio.get('/api/auth/profile.php');
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true && data['user'] is Map) {
        await ApiClient.saveCachedUser(Map<String, dynamic>.from(data['user']));
      }
    } catch (_) {}
  }

  // ── نوارِ پایین ──
  Widget _bottomBar(
    AppColors c,
    Color accent,
    int fullPrice,
    bool hasDiscount,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + navBarFootprint(context)),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.borderSoft)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (hasDiscount) ...[
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        toPersianDigits(groupThousands(fullPrice.toString())),
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        toPersianDigits(
                          '${groupThousands(_price.toString())} تومان',
                        ),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                Expanded(
                  flex: 4,
                  child: Text(
                    toPersianDigits(
                      '${groupThousands(_price.toString())} تومان',
                    ),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isPaying ? null : _startPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      disabledBackgroundColor: c.primary.withValues(alpha: 0.6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isPaying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 🔧 رفعِ باگِ «bottom overflowed»: چون عرضِ دکمه
                              // به ۶۰٪ محدود شد، این متنِ نسبتاً بلند دیگر جا
                              // نمی‌شد و به خطِ دوم می‌رفت — داخلِ ارتفاعِ ثابتِ
                              // ۴۸، همین یک‌خط‌شدنِ ناخواسته سرریز ایجاد می‌کرد
                              Flexible(
                                child: Text(
                                  'تأیید و رفتن به درگاه پرداخت',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
