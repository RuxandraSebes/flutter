import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../i18n/translations.dart';

/// Shows the PDF ingestion status — useful for hospital admins and doctors
/// to verify that Hipocrate reports are being picked up correctly.
///
/// Accessible from the doctor/admin AppBar via an info icon.
class IngestStatusScreen extends StatefulWidget {
  const IngestStatusScreen({super.key});

  @override
  State<IngestStatusScreen> createState() => _IngestStatusScreenState();
}

class _IngestStatusScreenState extends State<IngestStatusScreen> {
  String _tr(String key) => AppLocalizations.of(context).get(key);

  bool _loading = true;
  Map<String, dynamic>? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/ingest/status'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _status = json.decode(response.body);
          _loading = false;
        });
      } else {
        setState(() {
          _error = '${_tr('backend_server_returned')} ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '${_tr('connection_error')}: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: Text(_tr('hipocrate_ingest_status')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: _tr('refresh'),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A5276)))
          : _error != null
              ? _errorView()
              : _statusView(),
    );
  }

  Widget _errorView() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 12),
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: Text(_tr('retry')),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5276),
                foregroundColor: Colors.white),
          ),
        ]),
      );

  Widget _statusView() {
    final s = _status!;
    final recentLogs =
        List<Map<String, dynamic>>.from(s['recent_ingests'] ?? []);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary cards ─────────────────────────────────────────────────
          Row(children: [
            _statCard(
              label: _tr('ingest_pending'),
              value: '${s['pending_files'] ?? 0}',
              icon: Icons.hourglass_empty_outlined,
              color:
                  (s['pending_files'] ?? 0) > 0 ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 12),
            _statCard(
              label: _tr('documents_tab'),
              value: '${s['total_documents'] ?? 0}',
              icon: Icons.description_outlined,
              color: const Color(0xFF1A5276),
            ),
            const SizedBox(width: 12),
            _statCard(
              label: _tr('patients_tab'),
              value: '${s['total_patients'] ?? 0}',
              icon: Icons.people_outline,
              color: const Color(0xFF1A5276),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Watch directory ───────────────────────────────────────────────
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading:
                  const Icon(Icons.folder_outlined, color: Color(0xFF1A5276)),
              title: Text(_tr('monitored_directory'),
                  style:
                      const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(
                s['watch_dir'] ?? '—',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Recent ingestions ─────────────────────────────────────────────
          Text(_tr('recent_ingestions'),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A5276))),
          const SizedBox(height: 10),

          if (recentLogs.isEmpty)
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child: Text(_tr('no_ingestions'),
                        style: const TextStyle(color: Colors.grey))),
              ),
            )
          else
            ...recentLogs.map((log) => _logCard(log)),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) =>
      Expanded(
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ]),
          ),
        ),
      );

  Widget _logCard(Map<String, dynamic> log) {
    final status = log['status'] ?? 'unknown';
    final isOk = status == 'success';
    final color = isOk ? Colors.green.shade600 : Colors.red.shade600;
    final icon = isOk ? Icons.check_circle_outline : Icons.error_outline;

    final source = log['cnp_source'];
    final sourceLabel = source == 'explicit'
        ? _tr('ingest_source_explicit')
        : source == 'filename'
            ? _tr('ingest_source_filename')
            : source == 'pdf_text'
                ? _tr('ingest_source_pdf_text')
                : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          log['filename'] ?? '—',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          isOk
              ? '${_tr('ingest_cnp_from')}: $sourceLabel · '
                  '${log['patient_created'] == true ? _tr('ingest_new_patient') : _tr('ingest_existing_patient')}'
              : '${_tr('error')}: ${log['error_message'] ?? status}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: Text(
          _formatDate(log['created_at']),
          style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
        ),
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString().substring(0, 10);
    }
  }
}
