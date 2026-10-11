import 'package:shamsi_date/shamsi_date.dart';
import '../utils/persian_number.dart';

/// سطحِ اشتراکِ کاربرِ جاری
enum PlanLevel { free, silver, gold }

/// هر امکانی که ممکن است در پلن‌های پایین‌تر قفل شود
enum PlanFeature {
  // ── نوار پایین / داشبورد ──
  notifications,
  dailyPlan,

  // ── دراور ──
  delegatedTasks,
  entryExit,
  chat,
  monitoringTasks,
  monitoringRoutines,
  monitoringPayroll,
  managementUsers,
  managementActivitySections,
  managementGroups,
  managementAttendanceDevices,
  managementHolidays,
  managementSystemSettings,

  // ── تعریفِ کار / جزئیاتِ کار ──
  routineTask,
  assignToOthers,
  historyForDelegates,
  taskViewers,
  taskCreatorInfo,
  delegate,

  // ── پروفایل ──
  orgProfileFields,
}

/// منبعِ واحدِ حقیقتِ محدودیت‌های هر پلن. UI فقط از [allows] استفاده می‌کند.
///
/// کاربرِ جاری از فیلدِ `plan` در داده‌ی کاربر خوانده می‌شود (`free` /
/// `silver` / `gold`). اگر فیلد نبود یا ناشناخته بود، به‌عنوان طلایی
/// (بدونِ محدودیت) حساب می‌شود تا تا زمانِ آماده‌شدنِ بک‌اند، چیزی قفل نشود.
class PlanAccess {
  PlanAccess._();

  static PlanLevel _level = PlanLevel.gold;
  static PlanLevel get level => _level;

  static DateTime? _expiresAt;
  static int? _planUsers;
  static int? _usersUsed;
  static DateTime? _webTrialEndsAt;
  static bool _webAccess = false;

  /// سقفِ تعداد کاربر در پلنِ فعلی (null یعنی نامشخص)
  static int? get planUsers => _planUsers;

  /// تعدادِ کاربرانِ فعلیِ سازمان (null یعنی سرور این را نفرستاده)
  static int? get usersUsed => _usersUsed;

  /// پایانِ دوره‌ی آزمایشیِ دسترسی وب (null یعنی آزمایشی نیست)
  static DateTime? get webTrialEndsAt => _webTrialEndsAt;

  static bool get webAccess => _webAccess;

  /// تمدیدِ پلنِ طلایی فقط این تعداد روز مانده به انقضا ممکن است
  static const int goldRenewalWindowDays = 7;

  /// تاریخ انقضای پلنِ فعلی (null یعنی دائمی یا نامشخص)
  static DateTime? get expiresAt => _expiresAt;

  /// آیا می‌توان پلنِ [target] را خرید/انتخاب کرد؟
  /// اگر طلایی فعال است، فقط در بازه‌ی تمدید (چند روز قبل از انقضا) مجاز است.
  static bool canPurchase(PlanLevel target) {
    if (target != PlanLevel.gold || _level != PlanLevel.gold) return true;
    final exp = _expiresAt;
    if (exp == null) return false;
    final now = DateTime.now();
    final days = DateTime(
      exp.year,
      exp.month,
      exp.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    return days <= goldRenewalWindowDays;
  }

  static const Map<PlanLevel, Set<PlanFeature>> _locked = {
    PlanLevel.gold: <PlanFeature>{},
    PlanLevel.silver: <PlanFeature>{
      PlanFeature.notifications,
      PlanFeature.entryExit,
      PlanFeature.chat,
      PlanFeature.monitoringTasks,
      PlanFeature.monitoringRoutines,
      PlanFeature.monitoringPayroll,
      PlanFeature.managementActivitySections,
      PlanFeature.managementAttendanceDevices,
      PlanFeature.managementHolidays,
      PlanFeature.managementSystemSettings,
      PlanFeature.routineTask,
      PlanFeature.taskViewers,
      PlanFeature.delegate,
      PlanFeature.historyForDelegates,
    },
    PlanLevel.free: <PlanFeature>{
      PlanFeature.notifications,
      PlanFeature.dailyPlan,
      PlanFeature.delegatedTasks,
      PlanFeature.entryExit,
      PlanFeature.chat,
      PlanFeature.monitoringTasks,
      PlanFeature.monitoringRoutines,
      PlanFeature.monitoringPayroll,
      PlanFeature.managementUsers,
      PlanFeature.managementActivitySections,
      PlanFeature.managementAttendanceDevices,
      PlanFeature.managementHolidays,
      PlanFeature.managementSystemSettings,
      PlanFeature.routineTask,
      PlanFeature.assignToOthers,
      PlanFeature.historyForDelegates,
      PlanFeature.taskViewers,
      PlanFeature.taskCreatorInfo,
      PlanFeature.delegate,
      PlanFeature.orgProfileFields,
    },
  };

  /// از روی داده‌ی کاربر سطح را تعیین می‌کند (در ورود، ذخیره‌ی کاربر و
  /// ساختِ پوسته صدا زده می‌شود). سرور مقدارِ فارسی («رایگان»، «نقره‌ای»،
  /// «طلایی») و انگلیسی هر دو را می‌تواند بفرستد.
  ///
  /// 🔧 پنهان‌کردن فقط ظاهری است؛ امنیتِ واقعی با خطای 403 و کد
  /// PLAN_RESTRICTED در سرور است.
  static void setFromUser(Map<String, dynamic>? user) {
    final raw = user?['plan']?.toString().trim().toLowerCase();
    _level = switch (raw) {
      'free' || 'رایگان' => PlanLevel.free,
      'silver' || 'نقره‌ای' || 'نقره ای' || 'نقره' => PlanLevel.silver,
      _ => PlanLevel.gold,
    };
    _expiresAt = parsePlanDate(user?['plan_expires_at']);
    _planUsers = _parseInt(user?['plan_users']);
    _usersUsed = _parseInt(user?['plan_users_used']);
    _webTrialEndsAt = parsePlanDate(user?['web_trial_ends_at']);
    _webAccess = _parseBool(user?['web_access']);
  }

  /// پاک‌کردنِ سطح هنگامِ خروج
  static void reset() {
    _level = PlanLevel.gold;
    _expiresAt = null;
    _planUsers = null;
    _usersUsed = null;
    _webTrialEndsAt = null;
    _webAccess = false;
  }

  static int? _parseInt(dynamic v) =>
      int.tryParse(toEnglishDigits(v?.toString() ?? '').trim());

  static bool _parseBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = toEnglishDigits(v?.toString() ?? '').trim().toLowerCase();
    return const {'1', 'true', 'yes', 'active', 'فعال', 'بله'}.contains(s);
  }

  /// تاریخِ پلن را از هر قالبِ رایجِ سرور می‌خواند: میلادی (ISO یا
  /// Y-m-d H:i:s) یا شمسی (مثلاً ۱۴۰۵/۰۷/۱۲). ارقامِ فارسی هم پذیرفته است.
  static DateTime? parsePlanDate(dynamic raw) {
    final s = toEnglishDigits(raw?.toString() ?? '').trim();
    if (s.isEmpty) return null;
    final m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(s);
    if (m != null) {
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      // سال‌های کوچک‌تر از ۱۷۰۰ شمسی‌اند (مثلاً ۱۴۰۵)
      if (y < 1700) {
        return Jalali(y, mo, d).toDateTime();
      }
      return DateTime(y, mo, d);
    }
    return DateTime.tryParse(s);
  }

  static bool allows(PlanFeature feature) =>
      !_locked[_level]!.contains(feature);

  /// پایین‌ترینِ پلنی که این امکان را باز می‌کند (برایِ پیامِ ارتقا) —
  /// اگر پلنِ نقره‌ای هم آن را باز می‌کند، نتیجه نقره‌ای است، وگرنه طلایی
  static PlanLevel minPlanFor(PlanFeature feature) =>
      _locked[PlanLevel.silver]!.contains(feature)
      ? PlanLevel.gold
      : PlanLevel.silver;

  /// 🔧 طبق درخواست: پیامِ ارتقا باید دقیقاً پلنِ لازم را بگوید، نه همیشه
  /// «نقره‌ای یا طلایی» — مثلاً «مدیریت واحدهای فعالیت» فقط با طلایی باز
  /// می‌شود، نه با نقره‌ای
  static String requiredPlanLabel(PlanFeature feature) =>
      minPlanFor(feature) == PlanLevel.silver ? 'نقره‌ای یا طلایی' : 'طلایی';
}
