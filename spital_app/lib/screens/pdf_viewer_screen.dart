import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String name;

  const PdfViewerScreen({super.key, required this.url, required this.name});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  bool _loading = true;
  String? _error;
  int _pages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      // Build absolute URL
      final url = widget.url.startsWith('http')
          ? widget.url
          : 'http://10.0.2.2:8000/${widget.url.replaceFirst(RegExp(r'^/'), '')}';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        setState(() {
          _error = 'Nu s-a putut descărca (${response.statusCode})';
          _loading = false;
        });
        return;
      }

      final dir = await getTemporaryDirectory();
      final safeFileName = widget.name.replaceAll(RegExp(r'[^\w\.]'), '_');
      final file = File('${dir.path}/$safeFileName');
      await file.writeAsBytes(response.bodyBytes);

      if (mounted)
        setState(() {
          _localPath = file.path;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Eroare: $e';
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: Text(widget.name, style: const TextStyle(fontSize: 15)),
        actions: [
          if (_pages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text('$_currentPage / $_pages',
                    style: const TextStyle(color: Colors.white70)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF1A5276)),
                    SizedBox(height: 16),
                    Text('Se descarcă documentul...'),
                  ]),
            )
          : _error != null
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.red.shade400),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _downloadPdf();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reîncearcă'),
                        ),
                      ]),
                )
              : PDFView(
                  filePath: _localPath!,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  onRender: (pages) => setState(() => _pages = pages ?? 0),
                  onPageChanged: (page, _) =>
                      setState(() => _currentPage = (page ?? 0) + 1),
                  onError: (e) => setState(() => _error = e.toString()),
                ),
    );
  }
}
