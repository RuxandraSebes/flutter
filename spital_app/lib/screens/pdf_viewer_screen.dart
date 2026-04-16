import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String name;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.name,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final String fullUrl;

  @override
  void initState() {
    super.initState();

    fullUrl = widget.url.startsWith('http')
        ? widget.url
        : 'http://10.0.2.2:8000${widget.url}';

    if (kIsWeb) {
      // IMPORTANT: viewType trebuie să fie constant
      ui.platformViewRegistry.registerViewFactory(
        'pdf-viewer',
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = fullUrl
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';

          return iframe;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(child: Text("Use mobile viewer")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        backgroundColor: const Color(0xFF1A5276),
      ),
      body: const HtmlElementView(viewType: 'pdf-viewer'),
    );
  }
}
