import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/persian_number.dart';
import '../tasks/task_detail_page.dart';
import '../../core/utils/task_labels.dart';

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardPage({super.key, required this.user});
  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _stats;
  List<dynamic> _activities = [];
  bool _isLoading = true;
  bool _activitiesExpanded = false; // آکاردئون فعالیت‌ها — پیش‌فرض بسته

  static const _primary = Color(0xFF6D28D9);
  static const _primaryLight = Color(0xFF8B5CF6);
  static const _ink = Color(0xFF1A1A2E);
  static const _bg = Color(0xFFF7F7FB);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void reload() => _loadData();

  // 🔧 اصلاح سرعت: این دو درخواست از هم مستقل‌اند (آمار و فعالیت‌های
  // اخیر) — قبلاً پشت‌سرهم (sequential) گرفته می‌شدند که یعنی زمان لود
  // برابر با مجموع زمان دو درخواست بود. حالا هم‌زمان (parallel) گرفته
  // می‌شوند تا زمان لود تقریباً برابر با کندترینِ آن‌ها باشد، نه مجموعشان.
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([_fetchStats(), _fetchActivities()]);
    if (mounted) {
      setState(() {
        _stats = results[0] as Map<String, dynamic>?;
        _activities = results[1] as List<dynamic>;
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchStats() async {
    try {
      final res = await ApiClient.dio.get('/api/tasks/stats.php');
      if (res.data['success'] == true) return res.data['stats'];
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> _fetchActivities() async {
    try {
      final res = await ApiClient.dio.get(
        '/api/tasks/recent-activities.php',
        queryParameters: {'limit': 8},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) return data['activities'] ?? [];
    } catch (_) {}
    return [];
  }

  String _getShamsiDate() {
    final now = Jalali.now();
    const wd = [
      'شنبه',
      'یکشنبه',
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنجشنبه',
      'جمعه',
    ];
    const mo = [
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند',
    ];
    return toPersianDigits(
      '${wd[now.weekDay - 1]}، ${now.day} ${mo[now.month - 1]} ${now.year}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: _primary,
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 20),
                      _buildStatsGrid(),
                      const SizedBox(height: 24),
                      _buildActivitiesAccordion(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ── کارت خوش‌آمد گرادیان ──
  Widget _buildWelcomeCard() {
    final name =
        '${widget.user['first_name'] ?? ''} ${widget.user['last_name'] ?? ''}'
            .trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryLight, _primary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'خوش آمدید، ${name.isEmpty ? 'کاربر' : name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              const Text('👋', style: TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'امروز: ${_getShamsiDate()}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── گرید آماری ۲×۲ ──
  Widget _buildStatsGrid() {
    final total = _stats?['total'] ?? 0;
    final overdue = _stats?['overdue'] ?? 0;
    final completed = _stats?['completed'] ?? 0;
    final today = _stats?['today'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                value: total,
                label: 'کل کارها',
                icon: Icons.list_alt_rounded,
                color: _primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                value: overdue,
                label: 'عقب‌افتاده',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                value: completed,
                label: 'انجام‌شده',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                value: today,
                label: 'امروز',
                icon: Icons.today_rounded,
                color: const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required int value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toPersianDigits(value),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── آکاردئون فعالیت‌های اخیر (هدر قابل کلیک + محتوای بازشو) ──
  Widget _buildActivitiesAccordion() {
    final count = _activities.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // هدر قابل کلیک
        GestureDetector(
          onTap: () =>
              setState(() => _activitiesExpanded = !_activitiesExpanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              const Text(
                'فعالیت‌های اخیر',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              const SizedBox(width: 8),

              // شمارنده تعداد
              const Spacer(),
              // فلش چرخشی
              AnimatedRotation(
                turns: _activitiesExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade500,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
        // محتوای بازشو
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildActivitiesList(),
          ),
          crossFadeState: _activitiesExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildActivitiesList() {
    if (_activities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            'فعالیتی ثبت نشده',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: List.generate(_activities.length, (i) {
          final isLast = i == _activities.length - 1;
          return _activityItem(_activities[i], isLast);
        }),
      ),
    );
  }

  Widget _activityItem(Map<String, dynamic> act, bool isLast) {
    final action = act['action'] as String? ?? '';
    final actionLbl = TaskLabels.actionLabel(action);
    final actionClr = TaskLabels.actionColor(action);
    final actionIco = TaskLabels.actionIcon(action);
    final taskTitle = act['task_title'] ?? 'کار';
    final fromName = (act['from_user_name'] ?? '').toString().trim();
    final taskId = int.tryParse(act['task_id']?.toString() ?? '');

    return InkWell(
      onTap: taskId == null
          ? null
          : () async {
              await Get.to(
                () => TaskDetailPage(
                  taskId: taskId,
                  currentUserId: widget.user['id'],
                ),
              );
              _loadData();
            },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: actionClr.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(actionIco, color: actionClr, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: _ink,
                        fontFamily: 'Vazir',
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'کار «$taskTitle» ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: actionLbl),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    toPersianDigits(_timeAgo(act['created_at']?.toString())),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String? gregorian) {
    if (gregorian == null || gregorian.isEmpty) return '';
    try {
      final date = DateTime.parse(gregorian);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'همین الان';
      if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
      if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
      if (diff.inDays < 7) return '${diff.inDays} روز پیش';
      final j = Jalali.fromDateTime(date);
      const mo = [
        'فروردین',
        'اردیبهشت',
        'خرداد',
        'تیر',
        'مرداد',
        'شهریور',
        'مهر',
        'آبان',
        'آذر',
        'دی',
        'بهمن',
        'اسفند',
      ];
      return '${j.day} ${mo[j.month - 1]}';
    } catch (_) {
      return '';
    }
  }
}
