import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/network/api_client.dart';
import 'task_detail_page.dart';
import '../../core/utils/task_labels.dart';

class DelegatedTasksPage extends StatefulWidget {
  const DelegatedTasksPage({super.key});

  @override
  State<DelegatedTasksPage> createState() => _DelegatedTasksPageState();
}

class _DelegatedTasksPageState extends State<DelegatedTasksPage> {
  static const _primary = Color(0xFF6D28D9);
  static const _ink = Color(0xFF1A1A2E);

  List<dynamic> _tasks = [];
  bool _isLoading = true;
  String? _loadError;

  String _filter = 'همه';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final res = await ApiClient.dio.get('/api/tasks/delegated-tasks.php');
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        final list = data['tasks'];
        _tasks = list is List ? List<dynamic>.from(list) : [];
      } else {
        _loadError = data['message']?.toString() ?? 'خطا در دریافت کارها';
      }
    } catch (e) {
      _loadError = 'خطا در اتصال به سرور';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<dynamic> get _filteredTasks {
    var list = List<dynamic>.from(_tasks);

    if (_filter == 'در جریان') {
      list = list
          .where((t) => t['status'] != 'completed' && t['status'] != 'approved')
          .toList();
    } else if (_filter == 'تکمیل شده') {
      list = list
          .where((t) => t['status'] == 'completed' || t['status'] == 'approved')
          .toList();
    } else if (_filter == 'منتظر تأیید') {
      list = list.where((t) => t['status'] == 'pending_approval').toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim();
      list = list.where((t) {
        final title = (t['title'] ?? '').toString();
        final assignee = (t['assignee_name'] ?? '').toString();
        return title.contains(q) || assignee.contains(q);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7FB),
      child: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : Column(
                children: [
                  // عنوان صفحه
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'کارهای واگذارشده',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                    ),
                  ),
                  // جستجو
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'جستجو در عنوان یا نام مسئول...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey.shade400,
                          size: 22,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  // فیلترها
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: ['همه', 'در جریان', 'منتظر تأیید', 'تکمیل شده']
                          .map((f) {
                            final selected = _filter == f;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _filter = f),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected ? _primary : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    f,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // لیست
                  Expanded(
                    child: RefreshIndicator(
                      color: _primary,
                      onRefresh: _loadTasks,
                      child: _loadError != null
                          ? _buildErrorView()
                          : _filteredTasks.isEmpty
                          ? _buildEmpty()
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                100,
                              ),
                              itemCount: _filteredTasks.length,
                              itemBuilder: (ctx, i) =>
                                  _buildTaskCard(_filteredTasks[i]),
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorView() => ListView(
    children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
      Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _loadError ?? 'خطا',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('تلاش مجدد'),
              style: TextButton.styleFrom(foregroundColor: _primary),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _buildEmpty() => ListView(
    children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
      Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFF0EEFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_outlined, size: 48, color: _primary),
            ),
            const SizedBox(height: 16),
            Text(
              'کار واگذارشده‌ای وجود ندارد',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final status = task['status'] as String? ?? '';
    final priority = task['priority'] as String? ?? '';
    final statusLbl = TaskLabels.statusLabel(status);
    final statusClr = TaskLabels.statusColor(status);
    final assigneeName = (task['assignee_name'] ?? '').toString().trim();

    return GestureDetector(
      onTap: () async {
        final result = await Get.to(() => TaskDetailPage(taskId: task['id']));
        if (result == true) _loadTasks();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusClr,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task['title'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: _ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.flag_rounded,
                  color: TaskLabels.priorityColor(priority),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    assigneeName.isEmpty ? 'بدون مسئول' : assigneeName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _chip(statusLbl, statusClr),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
    ),
  );

  Color _priorityColor(String p) => switch (p) {
    'high' => const Color(0xFFEF4444),
    'medium' => const Color(0xFFF59E0B),
    'low' => const Color(0xFF22C55E),
    _ => Colors.grey.shade300,
  };
}
