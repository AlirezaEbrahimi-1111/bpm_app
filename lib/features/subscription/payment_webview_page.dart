import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';

/// نتیجه‌ی بازگشت از درگاهِ پرداخت — دقیقاً هم‌معنا با مقدارِ
/// query-paramِ «payment» که `api/payment/callback.php` در آدرسِ
/// بازگشتی می‌گذارد.
enum PaymentResult { success, already, cancel, failed, error, notfound }

/// صفحه‌ی پرداختِ زرین‌پال — داخلِ خودِ اپ (WebView)، بدونِ خروج به
/// مرورگرِ بیرونی. وقتی کاربر به صفحه‌ی نتیجه‌یِ سبکِ مخصوصِ اپ
/// (`/pages/payment-result.php`) برسد، این صفحه آن ناوبری را رصد
/// می‌کند، بدونِ این‌که بگذارد واقعاً لود شود، و نتیجه را برمی‌گرداند.
class PaymentWebviewPage extends StatefulWidget {
  final String paymentUrl;
  const PaymentWebviewPage({super.key, required this.paymentUrl});

  @override
  State<PaymentWebviewPage> createState() => _PaymentWebviewPageState();
}

class _PaymentWebviewPageState extends State<PaymentWebviewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && uri.path.contains('/pages/payment-result.php')) {
              _finish(_mapStatus(uri.queryParameters['payment']));
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  PaymentResult? _mapStatus(String? s) => switch (s) {
    'success' => PaymentResult.success,
    'already' => PaymentResult.already,
    'cancel' => PaymentResult.cancel,
    'failed' => PaymentResult.failed,
    'error' => PaymentResult.error,
    'notfound' => PaymentResult.notfound,
    _ => null,
  };

  void _finish(PaymentResult? result) {
    if (_resolved || !mounted) return;
    _resolved = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _finish(null);
      },
      child: Scaffold(
        backgroundColor: c.bgPage,
        appBar: AppBar(
          backgroundColor: c.bgPage,
          elevation: 0,
          iconTheme: IconThemeData(color: c.textStrong),
          title: Text(
            'درگاه پرداخت',
            style: TextStyle(
              color: c.textStrong,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              Center(child: CircularProgressIndicator(color: c.primary)),
          ],
        ),
      ),
    );
  }
}
