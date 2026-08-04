import 'package:flutter/material.dart';
import '../../../core/utils/task_labels.dart';

/// کارت نمایش یک کار — طراحی مشترک بین صفحه‌ی «کارهای من» و
/// «کارهای واگذارشده»، تا ظاهر هر دو صفحه دقیقاً یکسان باشد.
class TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTap;

  /// اگر true باشد، نام مسئولِ انجامِ کار هم نشان داده می‌شود
  /// (برای صفحه‌ی «کارهای واگذارشده» کاربردی است).
  final bool showAssignee;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.showAssignee = false,
  });

  static const _ink = Color(0xFF1A1A2E);
  static const _primary = Color(0xFF6D28D9);

  @override
  Widget build(BuildContext context) {
    final status = task['status'] as String? ?? '';
    final priority = task['priority'] as String? ?? '';
    final isDone = status == 'completed' || status == 'approved';
    final statusLbl = TaskLabels.statusLabel(status);
    final statusClr = TaskLabels.statusColor(status);
    final assigneeName = (task['assignee_name'] ?? '').toString().trim();
    final groupName = (task['group_name'] ?? '').toString().trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFF0EFF7) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isDone
              ? []
              : [
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
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? _primary : Colors.transparent,
                border: isDone
                    ? null
                    : Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDone ? Colors.grey.shade400 : _ink,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusClr,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          statusLbl,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showAssignee && assigneeName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: Colors.grey.shade300),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.person_outline_rounded,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            assigneeName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (!showAssignee && groupName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: Colors.grey.shade300),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.folder_outlined,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            groupName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.flag_rounded,
              color: TaskLabels.priorityColor(priority),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
