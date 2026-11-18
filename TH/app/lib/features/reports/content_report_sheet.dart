import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../chart/chart_view_model.dart';

Future<void> showContentReport(
  BuildContext context, {
  required String kind,
  required String id,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: panelColor,
  constraints: const BoxConstraints(maxWidth: 430),
  sheetAnimationStyle: FateMotion.dialog(context),
  builder: (_) => _ContentReport(
    kind: kind,
    id: id,
    owner: DependencyScope.of(context).session.owner,
  ),
);

class _ContentReport extends StatefulWidget {
  const _ContentReport({
    required this.kind,
    required this.id,
    required this.owner,
  });
  final String kind, id, owner;
  @override
  State<_ContentReport> createState() => _ContentReportState();
}

class _ContentReportState extends State<_ContentReport> {
  final _details = TextEditingController();
  String _requestKey = newRequestKey();
  String? _submittedPayload;
  String? _reason, _error, _receipt;
  bool _busy = false, _mayClose = false;

  Future<void> _close() async {
    if (_busy) return;
    if (_receipt == null && (_reason != null || _details.text.isNotEmpty)) {
      final s = AppLocalizations.of(context);
      final discard = await showDialog<bool>(
        context: context,
        animationStyle: FateMotion.dialog(context),
        builder: (context) => AlertDialog(
          content: Text(s.reportLeave),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.close),
            ),
          ],
        ),
      );
      if (!mounted || discard != true) return;
    }
    setState(() => _mayClose = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _send() async {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    if (_busy || _reason == null || d.session.owner != widget.owner) return;
    final payload = jsonEncode([_reason, _details.text.trim()]);
    if (_submittedPayload != null && _submittedPayload != payload) {
      _requestKey = newRequestKey();
    }
    _submittedPayload = payload;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await d.accountServices.reportContent(
        kind: widget.kind,
        id: widget.id,
        reason: _reason!,
        detail: _details.text.trim(),
        requestKey: _requestKey,
      );
      if (mounted && d.session.owner == widget.owner) {
        setState(() => _receipt = receipt);
      }
    } catch (_) {
      if (mounted) setState(() => _error = s.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: d.session,
      builder: (context, _) {
        final available =
            d.session.capabilities.contentReporting &&
            d.auth.hasSession &&
            d.session.owner == widget.owner;
        return PopScope(
          canPop: _mayClose,
          onPopInvokedWithResult: (popped, _) {
            if (!popped) _close();
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.contentReport,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    IconButton(
                      tooltip: s.close,
                      onPressed: _busy ? null : _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_receipt != null) ...[
                  const Center(
                    child: FateEmblem(Icons.check_rounded, size: 64),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(s.reportReceived(_receipt!)),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _close, child: Text(s.close)),
                ] else ...[
                  Text(
                    s.contentReportIntro,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Text(s.reportReason),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final entry in [
                        ('harmful', s.reasonHarmful),
                        ('sexual', s.reasonSexual),
                        ('hate', s.reasonHate),
                        ('privacy', s.reasonPrivacy),
                        ('misleading', s.reasonMisleading),
                        ('other', s.reasonOther),
                      ])
                        ChoiceChip(
                          label: Text(entry.$2),
                          selected: _reason == entry.$1,
                          onSelected: _busy
                              ? null
                              : (_) => setState(() => _reason = entry.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _details,
                    enabled: !_busy,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: InputDecoration(labelText: s.reportDetails),
                  ),
                  const SizedBox(height: 12),
                  if (!available)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        s.reportUnavailable,
                        style: const TextStyle(color: goldColor),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!),
                    ),
                  FilledButton(
                    onPressed: available && _reason != null && !_busy
                        ? _send
                        : null,
                    child: Text(_busy ? s.waiting : s.reportSend),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => context.push('/support'),
                    child: Text(s.supportTitle),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }
}
