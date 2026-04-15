import 'dart:io';
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
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      // Build absolute URL (replace 10.0.2.2:8000 with whatever base)
      final uri = Uri.parse(widget.url.startsWith('http')
          ? widget.url
          : 'http://10.0.2.2:8000${widget.url}');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${widget.name}');
        await file.writeAsBytes(response.bodyBytes);
        setState(() {
          _localPath = file.path;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Eroare la descărcarea PDF-ului (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Nu se poate deschide documentul: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: Text(widget.name, overflow: TextOverflow.ellipsis),
        actions: [
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Se descarcă documentul...',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 60),
                        const SizedBox(height: 16),
                        Text(_error!,
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Înapoi'),
                        ),
                      ],
                    ),
                  ),
                )
              : PDFView(
                  filePath: _localPath!,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  pageSnap: true,
                  fitPolicy: FitPolicy.BOTH,
                  onRender: (pages) => setState(() => _totalPages = pages ?? 0),
                  onPageChanged: (page, total) => setState(() {
                    _currentPage = page ?? 0;
                    _totalPages = total ?? 0;
                  }),
                  onError: (error) => setState(() => _error = error.toString()),
                ),
    );
  }
}
