import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';

Future<void> showHistory(BuildContext context, H5Controller h5) => showDialog(
  context: context,
  builder: (_) => HistoryDialog(h5: h5),
);

class HistoryDialog extends StatefulWidget {
  const HistoryDialog({required this.h5, super.key});
  final H5Controller h5;
  @override
  State<HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<HistoryDialog> {
  final _token = CancelToken();
  List<Json>? _items;
  String _error = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final data = object(
        await widget.h5.repository.request('/api/life-reports', _token),
      );
      if (mounted) setState(() => _items = objects(data['items']));
    } catch (error) {
      if (mounted && !_token.cancelled) {
        setState(() => _error = widget.h5.message(error));
      }
    }
  }

  @override
  void dispose() {
    _token.cancel();
    super.dispose();
  }

  void _open(Json item) {
    final language = text(object(object(item['input'])['profile'])['language']);
    Navigator.pop(context);
    context.go(
      '/report.html?id=${Uri.encodeComponent(text(item['id']))}&lang=$language${item['access'] == 'full' ? '' : '&checkout=1'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.h5.copy;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFF1C122D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x55E4BC78)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 410,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.t('jy', 'history'),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: c.t('jy', 'close'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 24, color: gold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                c.t('jy', 'historyHint'),
                style: const TextStyle(fontSize: 12, color: lavender),
              ),
              const SizedBox(height: 8),
              if (_items == null && _error.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_items != null)
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (_items!.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: line),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            c.t('jy', 'emptyHistory'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      for (final item in _items!)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: line),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.t(
                                        'jy',
                                        'topics.${object(item['input'])['career_question'] != null ? 'career' : 'life'}.label',
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _date(text(item['created_at'])),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: lavender,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: () => _open(item),
                                child: Text(
                                  c.t(
                                    'jy',
                                    item['access'] == 'full'
                                        ? 'openReport'
                                        : 'checkout.resume',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              errorMessage(_error),
              if (_error.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => _error = '');
                    unawaited(_load());
                  },
                  child: Text(c.t('generation', 'retry')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _date(String value) {
    final date = DateTime.tryParse(value)?.toLocal().toString();
    return date == null ? value : date.substring(0, 16);
  }
}
