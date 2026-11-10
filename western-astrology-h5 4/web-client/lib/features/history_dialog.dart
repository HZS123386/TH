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
  String? _deleting;

  Future<void> _delete(Json item) async {
    if (_deleting != null) return;
    final c = widget.h5.copy;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(c.t('experience', 'deleteTitle')),
        content: Text(c.t('experience', 'deleteNotice')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(c.t('experience', 'keep')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(c.t('experience', 'delete')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final id = text(item['id']);
    setState(() {
      _deleting = id;
      _error = '';
    });
    try {
      await widget.h5.repository.request(
        '/api/life-reports/${Uri.encodeComponent(id)}',
        _token,
        method: 'DELETE',
      );
      if (mounted) {
        setState(() => _items!.removeWhere((row) => row['id'] == id));
      }
    } catch (error) {
      if (mounted && !_token.cancelled) {
        setState(() => _error = widget.h5.message(error));
      }
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final c = widget.h5.copy;
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.t('life', 'history'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: c.t('life', 'close'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                c.t('life', 'historyHint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (_items == null && _error.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              if (_items != null)
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (_items!.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(25),
                          child: Text(c.t('life', 'emptyHistory')),
                        ),
                      for (final item in _items!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Panel(
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              title: Text(
                                '${object(object(item['input'])['profile'])['birth_date']} · ${object(item['input'])['year']}',
                              ),
                              subtitle: Text(
                                '${object(object(item['input'])['profile'])['birthplace']}\n${c.t('life', item['access'] == 'full' ? 'fullVersion' : 'previewVersion')} · ${c.t('life', 'open')}',
                              ),
                              trailing: IconButton(
                                tooltip: c.t('experience', 'delete'),
                                onPressed: _deleting == null
                                    ? () => unawaited(_delete(item))
                                    : null,
                                icon: _deleting == item['id']
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.delete_outline,
                                        size: 21,
                                        color: lavender,
                                      ),
                              ),
                              onTap: () {
                                final language = text(
                                  object(
                                    object(item['input'])['profile'],
                                  )['language'],
                                );
                                Navigator.pop(context);
                                context.go(
                                  '/report.html?id=${Uri.encodeComponent(text(item['id']))}&lang=$language',
                                );
                              },
                            ),
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
}
