// Встроенный просмотр 3D-тура (Kuula и аналоги) через WebView
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/theme.dart';
import '../widgets/piligrim_loader.dart';
import '../widgets/piligrim_tap.dart';

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
      ..setBackgroundColor(PiligrimColors.earthWarm)
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
      backgroundColor: PiligrimColors.earthWarm,
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
        leadingWidth: 80,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: PiligrimTap(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 2, 8, 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 12,
                    color: PiligrimColors.sky.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Назад',
                    style: PiligrimTextStyles.caption.copyWith(
                      color: PiligrimColors.sky.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          if (!_hasError)
            WebViewWidget(controller: _controller),

          if (_isLoading && !_hasError)
            const Center(child: PiligrimLoader()),

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
