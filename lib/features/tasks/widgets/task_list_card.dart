import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'task_badges.dart';
import 'task_quick_actions_sheet.dart';

/// کارتِ یک کار در لیست‌ها — مشترکِ صفحه‌ی «کارها» و «کارهای واگذارشده»
/// تا هر دو دقیقاً یک‌شکل باشند: ردیفِ اول = عنوان + بج + سه‌نقطه، و
/// موعد دقیقاً زیرِ عنوان (راست‌چین).
class TaskListCard extends StatelessWidget {
  final dynamic task;
  final VoidCallback onTap;
  final VoidCallback onChanged;

  /// طبق درخواست «نظارت بر کارها»: وقتی true، یک ردیفِ اضافه زیرِ موعد
  /// نشان می‌دهد که تعریف‌کننده و مسئولِ انجام چه کسانی هستند — برایِ
  /// صفحه‌های شخصی (کارها/واگذارشده) لازم نیست، چون معلوم است خودِ کاربر است
  final bool showPeople;

  const TaskListCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onChanged,
    this.showPeople = false,
  });

  bool get _isDone =>
      task['status'] == 'completed' ||
      task['status'] == 'approved' ||
      task['status'] == 'period_done';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final done = _isDone;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    task['title'] ?? '',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: done ? c.textMuted : c.textStrong,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final b in badgesForTask(task)) ...[
                      taskBadgeChip(icon: b.$1, label: b.$2, color: b.$3),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
                GestureDetector(
                  onTap: () => showTaskQuickActionsSheet(
                    context,
                    task: task,
                    onChanged: onChanged,
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
            taskDueRow(c, task),
            if (showPeople) _peopleRow(c),
          ],
        ),
      ),
    );
  }

  Widget _peopleRow(AppColors c) {
    final creator = (task['creator_name'] ?? '').toString().trim();
    final assignee = (task['assignee_name'] ?? '').toString().trim();
    if (creator.isEmpty && assignee.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            if (creator.isNotEmpty)
              _person(c, Icons.person_outline_rounded, 'تعریف‌کننده: $creator'),
            if (assignee.isNotEmpty)
              _person(c, Icons.assignment_ind_outlined, 'مسئول: $assignee'),
          ],
        ),
      ),
    );
  }

  Widget _person(AppColors c, IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: c.textMuted),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 11, color: c.textMuted)),
    ],
  );
}
