import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';

Future<bool?> showCheckout(
  BuildContext context,
  H5Controller h5,
  LifeReport report,
) => showDialog<bool>(
  context: context,
  builder: (_) => CheckoutDialog(h5: h5, report: report),
);

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({required this.h5, required this.report, super.key});
  final H5Controller h5;
  final LifeReport report;
  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog>
    with WidgetsBindingObserver {
  CancelToken? _request;
  Timer? _poll;
  Json? _order;
  String _error = '', _linkStatus = '';
  bool _filled = false, _submitted = false, _checking = false;
  Copy get c => widget.h5.copy.forReport(widget.report);
  bool get payso => widget.report.price['mode'] == 'payso_test';
  String t(String key) => c.t('checkout', key);
  String get link => Uri.base
      .resolve('report.html')
      .replace(
        queryParameters: {
          'id': widget.report.id,
          'lang': widget.report.language,
          'checkout': '1',
        },
      )
      .toString();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (payso) unawaited(_prepare());
  }

  Future<void> _prepare() async {
    _request?.cancel();
    final token = CancelToken();
    _request = token;
    setState(() => _error = '');
    try {
      final order = object(
        await widget.h5.repository.request(
          '/api/life-reports/${widget.report.id}/payment',
          token,
          body: {},
        ),
      );
      if (mounted && !token.cancelled) {
        final action = Uri.tryParse(text(order['action']));
        if (action == null ||
            action.scheme != 'https' ||
            object(order['fields']).isEmpty) {
          throw const FormatException('invalid_payment');
        }
        setState(() => _order = order);
        _schedule();
      }
    } catch (error) {
      if (mounted && !token.cancelled) {
        setState(() => _error = widget.h5.message(error));
      }
    }
  }

  void _schedule() {
    _poll?.cancel();
    if (mounted) _poll = Timer(const Duration(seconds: 5), () => _check());
  }

  Future<void> _check() async {
    if (_checking || !widget.h5.browser.visible) {
      _schedule();
      return;
    }
    _checking = true;
    try {
      final data = object(
        await widget.h5.repository.request(
          '/api/life-reports/${widget.report.id}/payment/check',
          _request!,
          body: {},
        ),
      );
      if (mounted && !_request!.cancelled) {
        if (data['paid'] == true) {
          Navigator.pop(context, true);
          return;
        }
        setState(() => _error = '');
      }
    } catch (error) {
      if (mounted && !_request!.cancelled) {
        setState(() => _error = widget.h5.message(error));
      }
    } finally {
      _checking = false;
      _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && payso && _order != null) {
      unawaited(_check());
    } else {
      _poll?.cancel();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _request?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(18),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    '✧ FATE',
                    style: TextStyle(
                      color: gold,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: t('close'),
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                t('title'),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t(payso ? 'payso' : 'demo'),
                style: const TextStyle(color: gold, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Panel(
                highlight: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.t('report', 'title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      t('once'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.report.priceLabel,
                      style: const TextStyle(
                        color: gold,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t('card'),
                style: const TextStyle(
                  color: gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (payso) ...[
                Text(
                  t('paysoHint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_order == null && _error.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Text(t('preparing')),
                  ),
                if (_order != null) ...[
                  Text(
                    '${t('order')} ${object(_order!['fields'])['refno'] ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      try {
                        widget.h5.browser.postPayment(
                          text(_order!['action']),
                          object(
                            _order!['fields'],
                          ).map((k, v) => MapEntry(k, '$v')),
                        );
                        setState(() => _submitted = true);
                      } catch (error) {
                        setState(() => _error = widget.h5.message(error));
                      }
                    },
                    child: Text(t('paysoOpen')),
                  ),
                  if (_submitted)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        t('paysoWaiting'),
                        style: const TextStyle(color: gold),
                      ),
                    ),
                ],
              ] else ...[
                Text(
                  c.t('report', 'direct'),
                  style: const TextStyle(color: gold, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: ValueKey('card-$_filled'),
                  readOnly: true,
                  initialValue: _filled ? '4242 4242 4242 4242' : '',
                  decoration: InputDecoration(
                    labelText: t('cardNumber'),
                    hintText: '0000 0000 0000 0000',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('expiry-$_filled'),
                        readOnly: true,
                        initialValue: _filled ? '12 / 30' : '',
                        decoration: InputDecoration(
                          labelText: t('expiry'),
                          hintText: 'MM / YY',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('security-$_filled'),
                        readOnly: true,
                        initialValue: _filled ? '123' : '',
                        decoration: InputDecoration(
                          labelText: t('securityCode'),
                          hintText: 'CVC',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  t('cardHint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton(
                  onPressed: _filled
                      ? null
                      : () => setState(() => _filled = true),
                  child: Text(t('fillCard')),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey('confirm-test-payment'),
                  onPressed: _filled
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: Text(
                    '${t('cardConfirm')} ${widget.report.priceLabel}',
                  ),
                ),
              ],
              errorMessage(_error),
              if (_error.isNotEmpty && _order == null && payso)
                TextButton(
                  onPressed: () => _prepare(),
                  child: Text(t('retry')),
                ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (mounted) setState(() => _linkStatus = t('copied'));
                  } catch (_) {
                    if (mounted) setState(() => _linkStatus = link);
                  }
                },
                icon: const Icon(Icons.link, size: 16),
                label: Text(t('link')),
              ),
              if (_linkStatus.isNotEmpty)
                SelectableText(
                  _linkStatus,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
