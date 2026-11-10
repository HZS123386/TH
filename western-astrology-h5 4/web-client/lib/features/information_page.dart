import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';

class InformationPage extends StatefulWidget {
  const InformationPage({this.support = false, super.key});
  final bool support;
  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  final _request = CancelToken();
  bool _loaded = false, _copied = false;
  String _email = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.support && !_loaded) {
      _loaded = true;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    try {
      final h5 = H5Scope.of(context);
      final data = object(
        await h5.repository.request(
          '/api/landing/config',
          _request,
          owned: false,
        ),
      );
      if (mounted) setState(() => _email = text(data['support_email']));
    } catch (_) {
      // The data-use explanation is readable even when support is unavailable.
    }
  }

  @override
  void dispose() {
    _request.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h5 = H5Scope.of(context), c = h5.copy;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/?lang=${h5.language}'),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: Text(c.t('experience', 'back')),
            ),
          ),
          const SizedBox(height: 12),
          SectionTitle(
            c.t('experience', widget.support ? 'support' : 'privacy'),
          ),
          if (widget.support) ...[
            Text(c.t('experience', 'supportNote')),
            const SizedBox(height: 20),
            if (_email.isEmpty)
              Text(
                c.t('experience', 'supportUnavailable'),
                style: const TextStyle(color: lavender),
              )
            else ...[
              SelectableText(_email, style: const TextStyle(color: gold)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _email));
                  if (mounted) setState(() => _copied = true);
                },
                icon: const Icon(Icons.copy, size: 16),
                label: Text(
                  _copied
                      ? (h5.language == 'zh' ? '已复制邮箱' : 'คัดลอกอีเมลแล้ว')
                      : (h5.language == 'zh' ? '复制邮箱' : 'คัดลอกอีเมล'),
                ),
              ),
            ],
          ] else ...[
            for (final paragraph in c.list('experience', 'privacyParagraphs'))
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Text(paragraph),
              ),
            TextButton(
              onPressed: () => context.go('/support.html?lang=${h5.language}'),
              child: Text(c.t('experience', 'support')),
            ),
          ],
        ],
      ),
    );
  }
}

Future<bool> confirmDataUse(BuildContext context, H5Controller h5) async {
  if (h5.noticeAccepted) return true;
  return await showDialog<bool>(
        context: context,
        builder: (_) => _DataUseDialog(h5: h5),
      ) ??
      false;
}

class _DataUseDialog extends StatefulWidget {
  const _DataUseDialog({required this.h5});
  final H5Controller h5;
  @override
  State<_DataUseDialog> createState() => _DataUseDialogState();
}

class _DataUseDialogState extends State<_DataUseDialog> {
  bool _saving = false, _details = false;
  String _error = '';

  Future<void> _accept() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await widget.h5.acceptDataUse();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = widget.h5.message(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.h5.copy;
    return AlertDialog(
      title: Text(c.t('experience', 'noticeTitle')),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.t('experience', 'notice')),
          TextButton(
            onPressed: () => setState(() => _details = !_details),
            child: Text(c.t('experience', 'privacy')),
          ),
          if (_details)
            for (final paragraph in c.list('experience', 'privacyParagraphs'))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  paragraph,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          errorMessage(_error),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(c.t('experience', 'cancel')),
        ),
        FilledButton(
          key: const ValueKey('data-use-agree'),
          onPressed: _saving ? null : () => unawaited(_accept()),
          child: Text(c.t('experience', 'agree')),
        ),
      ],
    );
  }
}
