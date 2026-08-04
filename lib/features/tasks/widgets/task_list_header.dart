import 'package:flutter/material.dart';

/// هدر مشترک صفحات لیست کار: عنوان + زیرعنوان اختیاری + جستجو + فیلترها.
/// برای یکسان کردن ظاهر «کارهای من» و «کارهای واگذارشده» استفاده می‌شود.
class TaskListHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String searchHint;
  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const TaskListHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.searchController,
    required this.onSearchChanged,
    required this.filters,
    required this.selectedFilter,
    required this.onFilterChanged,
    this.searchHint = 'جستجو بر اساس شناسه، عنوان یا توضیحات...',
  });

  static const _primary = Color(0xFF6D28D9);
  static const _ink = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
        const SizedBox(height: 16),

        // ── جستجو ──
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: searchHint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Colors.grey.shade400,
              size: 22,
            ),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── فیلترها ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final selected = f == selectedFilter;
              return GestureDetector(
                onTap: () => onFilterChanged(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(left: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? _primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected ? _primary : Colors.grey.shade500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
