// Встроенный просмотр 3D-тура (Kuula и аналоги) через WebView
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/theme.dart';

class TourWebViewScreen extends StatefulWidget {
  const TourWebViewScreen({super.key, required this.url});

  final String url;

  @override
  State<TourWebViewScreen> createState() => _TourWebViewScreenState();
}

class _TourWebViewScreenState extends State<TourWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1E1B19))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() { _isLoading = true; _hasError = false; });
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() { _isLoading = false; _hasError = true; });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1B19),
      appBar: AppBar(
        backgroundColor: PiligrimColors.earthDeep,
        foregroundColor: PiligrimColors.sky,
        elevation: 0,
        title: Text(
          'Виртуальный тур',
          style: PiligrimTextStyles.ctaLabel.copyWith(
            fontSize: 14,
            color: PiligrimColors.sky,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          if (!_hasError)
            WebViewWidget(controller: _controller),

          if (_isLoading && !_hasError)
            const Center(
              child: CircularProgressIndicator(
                color: PiligrimColors.water,
                strokeWidth: 2,
              ),
            ),

          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: PiligrimColors.sky.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Не удалось загрузить тур',
                      style: PiligrimTextStyles.body.copyWith(
                        color: PiligrimColors.sky.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        setState(() { _isLoading = true; _hasError = false; });
                        _controller.reload();
                      },
                      child: Text(
                        'Попробовать снова',
                        style: PiligrimTextStyles.ctaLabel.copyWith(
                          color: PiligrimColors.steppe,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
