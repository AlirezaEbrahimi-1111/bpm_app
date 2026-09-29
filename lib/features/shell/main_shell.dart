import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../../core/network/api_client.dart';
import '../../core/utils/persian_number.dart';
import '../dashboard/dashboard_page.dart';
import '../tasks/my_tasks_page.dart';
import '../notifications/notifications_page.dart';
import '../tasks/create_task_page.dart';
import '../settings/settings_page.dart';
import 'app_drawer.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/offline_banner.dart';
import 'widgets/global_search_sheet.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/notification_bar_preference.dart';

/// پوسته اصلی اپ: نوار پایین ثابت + جابجایی بین تب‌ها + Drawer
class MainShell extends StatefulWidget {
  final Map<String, dynamic> user;
  const MainShell({super.key, required this.user});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  // کلید Scaffold برای باز کردن Drawer از داخل صفحات
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // کلید برای دسترسی به state هر تب (برای refresh بعد از ساخت کار)
  final _myTasksKey = GlobalKey<MyTasksPageState>();
  final _dashboardKey = GlobalKey<DashboardPageState>();

  // 🔧 کنترلر PageView — برای این‌که با کشیدن (swipe) هم بشود بین تب‌ها
  // جابه‌جا شد، نه فقط با ضربه روی نوار پایین یا Drawer
  final _pageController = PageController();

  late final List<Widget> _pages;

  // 🔧 اصلاح: تعداد اعلان‌های نخوانده — برای نشان دادن روی آیکون زنگوله
  int _unreadCount = 0;
  Timer? _unreadPollTimer;

  // 🔧 اصلاح: دکمه‌ی فلشِ شناور نباید روی دراورِ بازشده بیفتد — چون در
  // یک Stack بیرون از کل Scaffold (و دراورش) رندر می‌شود، وقتی دراور
  // باز است این را مخفی/غیرقابل‌لمس می‌کنیم.
  bool _isDrawerOpen = false;

  // 🔧 طبق درخواست: دکمه‌ی فلشِ جستجوی سراسری کم‌رنگ/ناشناخته بود —
  // یک انیمیشنِ ملایمِ بالا-پایین (bob) پیوسته اضافه شد تا توجه را جلب کند
  late final AnimationController _searchBtnController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _searchBtnBob = Tween<double>(begin: 0, end: -6)
      .animate(
        CurvedAnimation(parent: _searchBtnController, curve: Curves.easeInOut),
      );

  // باز کردن Drawer — به صفحات پاس داده می‌شود
  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  void initState() {
    super.initState();
    // 🔧 اصلاح: «واگذارشده» از نوارِ پایین/PageView حذف شد (فقط از
    // دراور در دسترس است) و «تنظیمات» به‌جایش اضافه شد — طبقِ درخواست،
    // تنظیمات هم باید هدر/نوارِ پایینِ مشترک را داشته باشد، پس حالا
    // خودش یک تبِ واقعیِ این PageView است (index=1)، نه یک صفحه‌ی
    // جداگانه‌ی push‌شده
    _pages = [
      DashboardPage(
        key: _dashboardKey,
        user: widget.user,
        onSeeAllTasks: () => _onTabTapped(3),
      ),
      const SettingsPage(),
      NotificationsPage(
        onUnreadCountChanged: (count) {
          if (mounted) setState(() => _unreadCount = count);
        },
      ),
      MyTasksPage(key: _myTasksKey, user: widget.user),
    ];

    // 🔧 همان لحظه‌ی باز شدن اپ، یک‌بار تعداد نخوانده‌ها را می‌گیریم...
    _loadUnreadCount();
    // ...و بعد هر ۳۰ ثانیه دوباره چک می‌کنیم، تا حتی وقتی کاربر توی
    // تبِ اعلان‌ها نیست هم، عدد روی زنگوله به‌روز بماند.
    _unreadPollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadUnreadCount(),
    );
  }

  @override
  void dispose() {
    _unreadPollTimer?.cancel();
    _pageController.dispose();
    _searchBtnController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final res = await ApiClient.dio.get('/api/notifications/list.php');
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true && mounted) {
        setState(() => _unreadCount = data['unread_count'] ?? 0);
      }
    } catch (_) {
      // خطای شمارش اعلان نباید کل اپ را مختل کند
    }
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
    // 🔧 اصلاح باگِ کندی/ناپایداریِ لودِ تب‌ها: animateToPage بین دو تبِ
    // غیرمجاور (مثلاً داشبورد → اعلان‌ها)، از وسطِ تب‌های «کارها» و
    // «واگذارشده» هم رد می‌شود و باعث می‌شود آن‌ها هم بدونِ نیاز ساخته و
    // بارگذاری شوند — یعنی با یک ضربه روی نوار پایین، هر ۴ تب هم‌زمان
    // به سرور درخواست می‌فرستند (و صفحاتِ «کارها»/«واگذارشده» هم به‌دنبالش
    // برای هر آیتمِ لیست یک درخواستِ جداگانه‌ی پیش‌بارگیری). jumpToPage
    // مستقیم به تبِ مقصد می‌رود، بدون رد شدن از وسط.
    _pageController.jumpToPage(index);
  }

  Future<void> _openCreateTask() async {
    final result = await Get.to(
      () => CreateTaskPage(
        userRole: widget.user['role'] ?? '',
        currentUserId: widget.user['id'],
      ),
    );
    if (result == true) {
      _dashboardKey.currentState?.reload();
      _myTasksKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        _buildScaffold(c),
        // 🔧 دکمه‌ی «فلش رو به بالا» — شناور و جدا از نوار پایین/دکمه‌ی
        // «+»، در همه‌ی صفحات (چون این‌جا در پوسته‌ی اصلی است، نه داخل
        // یک تب خاص) — با ضربه، کادر جستجوی سراسری باز می‌شود.
        // فاصله‌ی این عدد از پایین به‌گونه‌ای انتخاب شده که کاملاً بالاتر
        // از نوکِ دکمه‌ی «+» (که کمی پایین‌تر آورده شده) بماند و رویش
        // نیفتد.
        Positioned(
          // 🔧 نوارِ پایین به لبه‌ی صفحه چسبیده — فوتپرینتِ کلِ آن از
          // پایینِ صفحه برابرِ «ارتفاعِ خودِ کارت (۶۲) + inset سیستم» است
          bottom: 62 + MediaQuery.of(context).padding.bottom + 36,
          // 🔧 اصلاح: در تبِ «کارها» (index=3 در PageView جدید) خودِ
          // صفحه یک جستجوی اختصاصی در بالا دارد — دکمه‌ی فلشِ جستجوی
          // سراسری همان‌جا اضافه و گمراه‌کننده است، پس فقط در این تب
          // مخفی می‌شود
          child: IgnorePointer(
            ignoring: _isDrawerOpen || _selectedIndex == 3,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: (_isDrawerOpen || _selectedIndex == 3) ? 0 : 1,
              child: GestureDetector(
                onTap: () => showGlobalSearchSheet(context),
                // 🔧 طبق درخواست: انیمیشنِ بالا-پایینِ پیوسته تا این دکمه
                // (که قبلاً کم‌رنگ و گمنام بود) واضح و قابلِ‌توجه باشد
                child: AnimatedBuilder(
                  animation: _searchBtnBob,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _searchBtnBob.value),
                    child: child,
                  ),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: c.primary.withValues(alpha: 0.15),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: c.primary,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScaffold(AppColors c) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: c.bgPage,
      // 🔧 اصلاح: بدونِ این، محتوای صفحه زیرِ نوارِ پایین امتداد پیدا
      // نمی‌کرد — پشتِ BackdropFilterِ نوار همیشه فقط رنگِ صافِ
      // bgPage (نزدیک به سفید) بود، نه محتوایِ واقعیِ صفحه؛ یعنی
      // «شیشه‌ای» بودنِ نوار عملاً هیچ اثری نداشت
      extendBody: true,
      drawer: AppDrawer(
        user: widget.user,
        currentIndex: _selectedIndex,
        onTabSelected: _onTabTapped,
      ),
      onDrawerChanged: (isOpen) => setState(() => _isDrawerOpen = isOpen),
      // 🔧 اصلاح: دکمه‌ی همبرگری و آیکون پروفایل حالا بیرون از PageView
      // و فقط یک‌بار رندر می‌شوند — مثل هدر یک سایت، ثابت می‌مانند و با
      // جابه‌جایی/کشیدن بین تب‌ها تکان نمی‌خورند؛ فقط محتوای زیرشان عوض
      // می‌شود.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppTopBar(user: widget.user, onMenuTap: _openDrawer),
            // 🔧 اصلاح: نوار «بدون اینترنت» هم مثل نوار بالا، فقط یک‌بار
            // و همیشه دقیقاً همین‌جا رندر می‌شود — نه داخل هر صفحه با
            // جای متفاوت. این‌طور در همه‌ی تب‌ها دقیقاً یک‌شکل است.
            // 🔧 نمایشِ این نوار حالا به سوییچِ «نمایش نوار اعلان» در
            // صفحه‌ی تنظیمات هم بستگی دارد
            ValueListenableBuilder<bool>(
              valueListenable: NotificationBarPreference.isEnabledNotifier,
              builder: (context, barEnabled, _) {
                if (!barEnabled) return const SizedBox.shrink();
                return ValueListenableBuilder<bool>(
                  valueListenable: ConnectivityService.instance.isOnline,
                  builder: (context, online, _) {
                    if (online) return const SizedBox.shrink();
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: OfflineBanner(),
                    );
                  },
                );
              },
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _selectedIndex = index),
                children: _pages,
              ),
            ),
          ],
        ),
      ),
      // 🔧 طبق درخواست: کمی بزرگ‌تر از حالت استاندارد (۵۶ → ۶۴)
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FittedBox(
          child: FloatingActionButton(
            onPressed: _openCreateTask,
            backgroundColor: c.primary,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
      // 🔧 اصلاح: کمی پایین‌تر از حالت استاندارد centerDocked — تا با
      // دکمه‌ی فلشِ بالای نوار برخورد نکند
      floatingActionButtonLocation: const _LoweredDockedFabLocation(),
      bottomNavigationBar: _buildBottomNav(c),
    );
  }

  // 🔧 اصلاح طبقِ درخواست: ترتیبِ جدید «داشبورد، تنظیمات، اعلان‌ها،
  // کارها» — «واگذارشده» از نوارِ پایین حذف شد (فقط از دراور در
  // دسترس است) و «تنظیمات» جایگزینش شد. تنظیمات هم هدر/نوارِ پایینِ
  // مشترک را دارد (index=1 در PageView)، پس مثلِ بقیه‌ی تب‌ها با
  // jumpToPage جابه‌جا می‌شود، نه push.
  //
  // 🔧 اصلاح طبقِ درخواست: نوار پایین باید به پایینِ واقعیِ صفحه
  // بچسبد (نه شناور با فاصله از پایین) — فقط از چپ/راست فاصله دارد و
  // فقط گوشه‌های بالا گرد است؛ فاصله‌ی سیستمی (دکمه‌های ناوبریِ گوشی)
  // با SafeAreaِ داخلی رعایت می‌شود، نه با مارجینِ بیرونی.
  Widget _buildBottomNav(AppColors c) {
    // 🔧 اصلاح: رنگِ تونالِ استاندارد (طبقِ Material 3 surface-container) —
    // در روشن، تنی فقط کمی تیره‌تر از سفید؛ در تاریک کمی روشن‌تر از
    // پس‌زمینه. حالا که Scaffold با extendBody محتوایِ واقعیِ صفحه را
    // زیرِ این نوار می‌آورد، شفافیت را کم کردیم تا بلور واقعاً محتوا
    // را نشان دهد (شیشه‌ای واقعی)، نه فقط یک رنگِ صافِ پشتِ آن.
    // 🔧 طبق درخواست: مستطیلِ ساده با هر چهار گوشه‌ی خیلی گرد (بدونِ
    // فرورفتگیِ دکمه‌ی +)، شناور با ۱۲ پیکسل فاصله از پایین؛ SafeArea
    // حالا بیرونِ کارت است تا فاصله‌ی دکمه‌های گوشی جدا از خودِ کارت بماند.
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        // 🔧 عرضِ نوار = ۹۰٪ عرضِ صفحه (وسط‌چین)
        widthFactor: 0.9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            // 🔧 BottomAppBar حذف شد: ارتفاعِ پیش‌فرضِ آن (Material 3) مانعِ
            // کوتاه‌کردنِ نوار بود؛ حالا ارتفاع دقیقاً همان عددِ height است
            child: ColoredBox(
              color: c.navBarBg.withValues(alpha: 0.75),
              child: SizedBox(
                height: 70,
                child: Padding(
                  // فشرده‌تر از اطراف: گزینه‌ها از لبه‌ها به مرکز نزدیک می‌شوند
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _navItem(
                        c: c,
                        icon: Icons.grid_view_rounded,
                        label: 'داشبورد',
                        selected: _selectedIndex == 0,
                        onTap: () => _onTabTapped(0),
                      ),
                      _navItem(
                        c: c,
                        icon: Icons.settings_outlined,
                        label: 'تنظیمات',
                        selected: _selectedIndex == 1,
                        onTap: () => _onTabTapped(1),
                      ),
                      const SizedBox(
                        width: 64,
                      ), // جای خالیِ دکمه‌ی شناور در وسط
                      _navItem(
                        c: c,
                        icon: Icons.notifications_rounded,
                        label: 'اعلان‌ها',
                        selected: _selectedIndex == 2,
                        showBadge: _unreadCount > 0,
                        onTap: () => _onTabTapped(2),
                      ),
                      _navItem(
                        c: c,
                        icon: Icons.task_alt_rounded,
                        label: 'کارها',
                        selected: _selectedIndex == 3,
                        onTap: () => _onTabTapped(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔧 اصلاح: عنوان حالا زیرِ آیکون است (نه کنارش) تا جا بیشتری بگیرد،
  // و همیشه نمایش داده می‌شود (نه فقط برای تبِ فعال) — برای تب‌های
  // غیرفعال با رنگِ کم‌رنگ‌تر (textMuted) به‌جای سفیدِ پررنگ.
  Widget _navItem({
    required AppColors c,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        // OverflowBox: اگر height نوار کمتر از اندازه‌ی آیکن شد، آیکن
        // بریده/سرریز نشود و وسطِ نوار بماند
        child: OverflowBox(
          maxHeight: 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 26,
                    color: selected ? c.primary : c.textMuted,
                  ),
                  if (showBadge)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 15,
                          minHeight: 15,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c.navBarBg, width: 1.5),
                        ),
                        child: Text(
                          _unreadCount > 99
                              ? '${toPersianDigits('99')}+'
                              : toPersianDigits(_unreadCount.toString()),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? c.primary : c.textMuted,
                  fontFamily: 'Vazir',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// همان مکان استانداردِ centerDocked، فقط کمی پایین‌تر — تا دکمه‌ی «+»
/// کمتر از لبه‌ی بالای نوار پایین بیرون بزند و با دکمه‌ی فلشِ بالای
/// نوار تداخل نداشته باشد.
class _LoweredDockedFabLocation extends FloatingActionButtonLocation {
  const _LoweredDockedFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final standard = FloatingActionButtonLocation.centerDocked.getOffset(
      scaffoldGeometry,
    );
    // مرکزِ دکمه ۲۰ پیکسل زیرِ لبه‌ی بالای نوار (نوار ۶۲ پیکسل ارتفاع
    // دارد و مرکزِ گزینه‌هایش ۳۱ پیکسل پایین‌تر است، پس دکمه کمی بالاتر
    // از بقیه می‌نشیند). عدد را کمتر کنید تا بالاتر برود.
    return Offset(standard.dx, standard.dy + 12);
  }
}
