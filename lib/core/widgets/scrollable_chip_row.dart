import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// ردیفِ افقیِ قابلِ‌اسکرولِ چیپ/دکمه — با فلشِ چپ/راست که فقط در جهتی
/// که هنوز محتوایِ پنهان هست پررنگ می‌شود و با ضربه، ردیف را همان سمت
/// می‌لغزاند. برایِ هر جایی که تعداد چیپ‌ها/دکمه‌ها ممکن است از عرضِ
/// صفحه بیشتر شود (نوارِ اکشنِ جزئیاتِ تسک، فیلترهایِ نظارت بر روتین‌ها و ...)
class ScrollableChipRow extends StatefulWidget {
  final List<Widget> children;
  final double gap;

  const ScrollableChipRow({super.key, required this.children, this.gap = 10});

  @override
  State<ScrollableChipRow> createState() => _ScrollableChipRowState();
}

class _ScrollableChipRowState extends State<ScrollableChipRow> {
  final _controller = ScrollController();
  bool _canGoLeft = false;
  bool _canGoRight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // در راست‌به‌چپ، شروعِ اسکرول (offset = 0) سمتِ راست است؛ افزایشِ offset
  // یعنی رفتن به چپ
  void _update() {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final left = p.pixels < p.maxScrollExtent - 1;
    final right = p.pixels > 1;
    if (left != _canGoLeft || right != _canGoRight) {
      setState(() {
        _canGoLeft = left;
        _canGoRight = right;
      });
    }
  }

  void _scrollBy(double delta) {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    _controller.animateTo(
      (p.pixels + delta).clamp(0.0, p.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _arrow(AppColors c, {required bool left, required bool enabled}) {
    // LTR اجباری: تا فلشِ «چپ» واقعاً به چپ اشاره کند (در RTL آینه می‌شود)
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => _scrollBy(left ? 140 : -140) : null,
        child: SizedBox(
          width: 22,
          height: 36,
          child: Icon(
            left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            size: 24,
            color: enabled ? c.primary : Colors.transparent,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        _arrow(c, left: false, enabled: _canGoRight),
        Expanded(
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < widget.children.length; i++) ...[
                  widget.children[i],
                  if (i != widget.children.length - 1)
                    SizedBox(width: widget.gap),
                ],
              ],
            ),
          ),
        ),
        _arrow(c, left: true, enabled: _canGoLeft),
      ],
    );
  }
}
