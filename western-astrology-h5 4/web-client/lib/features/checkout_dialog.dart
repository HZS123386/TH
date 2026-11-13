import 'dart:async';
import 'package:flutter/material.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';
import '../ui/jy_components.dart';

class ReportCheckout extends StatefulWidget {
  const ReportCheckout({
    required this.h5,
    required this.report,
    required this.freePreview,
    required this.onBack,
    required this.onErase,
    this.onPay,
    this.busy = false,
    this.error = '',
    super.key,
  });
  final H5Controller h5;
  final LifeReport report;
  final VoidCallback onBack, onErase;
  final VoidCallback? onPay;
  final Widget freePreview;
  final bool busy;
  final String error;
  @override
  State<ReportCheckout> createState() => _ReportCheckoutState();
}

class _ReportCheckoutState extends State<ReportCheckout> {
  bool _downloadNotice = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.h5.copy;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.84),
          radius: 1.4,
          colors: [Color(0xFF392353), Color(0xFF160D29), Color(0xFF0C0816)],
          stops: [0, .5, 1],
        ),
      ),
      child: SingleChildScrollView(
        key: const ValueKey('report-checkout'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FateBrand(compact: true),
              const SizedBox(height: 20),
              widget.freePreview,
              const SizedBox(height: 28),
              Text(
                c.t('jy', 'checkout.eyebrow'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: gold),
              ),
              const SizedBox(height: 4),
              Text(
                c.t('jy', 'checkout.title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.25,
                  color: Color(0xFFFFEDCC),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              JYCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                radius: 18,
                borderColor: const Color(0xFFDFB675),
                colors: const [Color(0xFF4C3263), Color(0xFF241732)],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0x70E4BC78)),
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF67435C), Color(0xFF51335D)],
                        ),
                      ),
                      child: Text(
                        '✧  ${c.t('jy', 'checkout.contents')}  ✧',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFFFFE3AA),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ReportBadges(copy: c),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0x40E4BC78)),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          c.t('jy', 'checkout.samplePrice'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFF7D69E),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.report.canPay
                              ? widget.report.priceLabel
                              : '฿39',
                          style: const TextStyle(
                            fontSize: 27,
                            color: Color(0xFFF7D69E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    JYButton(
                      key: const ValueKey('jy-payment-preview'),
                      label: widget.report.orderOnly
                          ? c.t('checkout', 'openCashier')
                          : c.t('jy', 'checkout.pay'),
                      icon: 'lock',
                      onPressed: widget.busy ? null : widget.onPay,
                      dimDisabled: false,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      widget.report.canPay
                          ? c.t(
                              'checkout',
                              widget.report.orderOnly ? 'orderOnlyHint' :
                              widget.report.paysoTest ? 'payso' : 'demoHint',
                            )
                          : c.t('jy', 'checkout.preview'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: lavender),
                    ),
                    const SizedBox(height: 14),
                    JYButton(
                      key: const ValueKey('jy-app-download'),
                      label: c.t('jy', 'checkout.download'),
                      icon: 'download',
                      pulse: true,
                      onPressed: () => setState(() => _downloadNotice = true),
                    ),
                    if (_downloadNotice)
                      Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            c.t('jy', 'checkout.downloadUnavailable'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: lavender),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              JYCard(
                padding: const EdgeInsets.fromLTRB(13, 17, 13, 15),
                radius: 16,
                borderColor: const Color(0x70E4BC78),
                colors: const [Color(0xFF624162), Color(0xFF261733)],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in c.list('jy', 'checkout.aboutTitle'))
                      Text(
                        line,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFE1A1),
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFF4D9A8)),
                        borderRadius: BorderRadius.circular(11),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF1D5), Color(0xFFF3DAB6)],
                        ),
                      ),
                      child: Text(
                        c.t('jy', 'checkout.about'),
                        style: const TextStyle(
                          color: Color(0xFF44283E),
                          fontSize: 14,
                          height: 1.65,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: widget.busy ? null : widget.onBack,
                    child: Text(c.t('jy', 'checkout.back')),
                  ),
                  OutlinedButton(
                    onPressed: widget.busy ? null : widget.onErase,
                    child: Text(c.t('jy', 'erase')),
                  ),
                ],
              ),
              errorMessage(widget.error),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportPaymentDialog extends StatefulWidget {
  const ReportPaymentDialog({
    required this.h5,
    required this.report,
    super.key,
  });

  final H5Controller h5;
  final LifeReport report;

  @override
  State<ReportPaymentDialog> createState() => _ReportPaymentDialogState();
}

class _ReportPaymentDialogState extends State<ReportPaymentDialog> {
  final _request = CancelToken();
  final _mobile = TextEditingController();
  final _nationCode = TextEditingController(text: '66');
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _securityCode = TextEditingController();
  PaymentOrder? _order;
  bool _preparing = false, _waiting = false, _paid = false;
  bool _canRetry = true;
  bool _existingChecked = false;
  String _error = '';

  Copy get _copy => widget.h5.copy.forReport(widget.report);

  @override
  void initState() {
    super.initState();
    unawaited(_prepare(existingOnly: widget.report.orderOnly));
  }

  Future<void> _prepare({bool existingOnly = false}) async {
    if (_preparing || _request.cancelled || !_canRetry) return;
    final mobile = _mobile.text.trim().replaceAll(RegExp(r'[ \t()-]'), '');
    final nationCode = _nationCode.text.trim().replaceFirst(RegExp(r'^\+'), '');
    if (widget.report.orderOnly && !existingOnly &&
        (!RegExp(r'^[0-9]{6,14}$').hasMatch(mobile) ||
         !RegExp(r'^[1-9][0-9]{0,2}$').hasMatch(nationCode) ||
         mobile.length + nationCode.length > 15)) {
      setState(() => _error = _copy.t('checkout', 'life_order_phone_invalid'));
      return;
    }
    setState(() {
      _preparing = true;
      _error = '';
      _canRetry = true;
    });
    final repository = widget.h5.repository;
    try {
      try {
        // Reopening reads the saved order; only the explicit create button can submit one.
        final order = existingOnly
            ? await repository.existingPayment(widget.report, _request)
            : await repository.createPayment(widget.report, _request,
                mobile: mobile, nationCode: nationCode);
        if (mounted) {
          setState(() {
            _order = order;
            if (existingOnly) _existingChecked = true;
          });
        }
        if (mounted && widget.report.orderOnly && order != null) _startWaiting();
      } on ApiFailure catch (error) {
        if (widget.report.orderOnly || error.status != 409 ||
            !await repository.checkPayment(widget.report, _request)) {
          rethrow;
        }
        if (mounted) { await _showSuccess(); }
      }
    } catch (error) {
      if (mounted && !_request.cancelled) {
        final code = error is ApiFailure ? error.code : '';
        final label = switch (code) {
          'life_order_configuration_required' => 'configurationRequired',
          'life_order_access_denied' => 'accessDenied',
          'life_order_rejected' => 'orderRejected',
          'life_order_channel_invalid' => 'channelInvalid',
          'life_order_needs_review' => 'orderNeedsReview',
          _ => '',
        };
        setState(() {
          // A saved, explicit gateway denial has no upstream order and permits manual phone entry.
          if (existingOnly && code == 'life_order_access_denied') _existingChecked = true;
          _canRetry = !widget.report.orderOnly ||
              (code != 'life_order_needs_review' && code != 'life_order_rejected' && code != 'life_order_channel_invalid');
          _error = label.isEmpty
              ? widget.h5.message(error, labels: _copy)
              : _copy.t('checkout', label);
        });
      }
    } finally {
      if (mounted && !_request.cancelled) setState(() => _preparing = false);
    }
  }

  void _openSunlands() {
    final url = _order?.checkoutUrl;
    if (url == null || url.isEmpty) return;
    try {
      widget.h5.browser.openPage(url);
    } catch (error) {
      setState(() => _error = widget.h5.message(error, labels: _copy));
      return;
    }
    _startWaiting();
  }

  void _openPayso() {
    final order = _order;
    if (order == null) return;
    try {
      // Submit from the tap so browsers can open the hosted checkout tab.
      widget.h5.browser.postPayment(order.action, order.fields);
    } catch (error) {
      setState(() => _error = widget.h5.message(error, labels: _copy));
      return;
    }
    _startWaiting();
  }

  void _startWaiting({bool immediately = false}) {
    if (_waiting || _paid || _request.cancelled) return;
    setState(() {
      _waiting = true;
      _error = '';
    });
    unawaited(_waitForPayment(immediately: immediately));
  }

  Future<void> _waitForPayment({bool immediately = false}) async {
    const interval = Duration(seconds: 5);
    var delay = immediately ? Duration.zero : interval;
    try {
      while (mounted) {
        await _request.pause(delay);
        delay = interval;
        if (!widget.h5.browser.visible) continue;
        try {
          final paid = await widget.h5.repository.checkPayment(
            widget.report,
            _request,
          );
          if (!mounted) return;
          if (paid) {
            await _showSuccess();
            return;
          }
          delay = interval;
          if (_error.isNotEmpty) setState(() => _error = '');
        } on ApiFailure catch (error) {
          if (!mounted) return;
          setState(() => _error = widget.h5.message(error, labels: _copy));
          if (error.status == 404 || error.status == 409 ||
              error.code == 'life_payment_check_access_denied') {
            return;
          }
          final retryAfter = error.retryAfter;
          delay = retryAfter != null && retryAfter > interval
              ? retryAfter
              : interval;
        } catch (error) {
          if (error is Cancelled) rethrow;
          if (mounted) { setState(() => _error = widget.h5.message(error, labels: _copy)); }
          delay = const Duration(seconds: 15);
        }
      }
    } on Cancelled {
      // Closing the dialog cancels the in-flight check and timer.
    } finally {
      if (mounted && !_request.cancelled) setState(() => _waiting = false);
    }
  }

  Future<void> _simulatePayment() async {
    final order = _order;
    if (order == null || _waiting || _paid) return;
    // Only the local test card is accepted; card fields never leave this dialog.
    if (_cardNumber.text.replaceAll(' ', '') != '4242424242424242' ||
        _expiry.text.replaceAll(' ', '') != '12/30' ||
        _securityCode.text != '123') {
      setState(() => _error = _copy.t('checkout', 'cardHint'));
      return;
    }
    setState(() {
      _waiting = true;
      _error = '';
    });
    try {
      await widget.h5.repository.simulatePayment(
        widget.report,
        order,
        _request,
      );
      if (mounted) { await _showSuccess(); }
    } catch (error) {
      if (mounted && !_request.cancelled) {
        setState(() => _error = widget.h5.message(error, labels: _copy));
      }
    } finally {
      if (mounted && !_request.cancelled) setState(() => _waiting = false);
    }
  }

  Future<void> _showSuccess() async {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    setState(() {
      _paid = true;
      _error = '';
    });
    await _request.pause(const Duration(seconds: 2));
    if (mounted) _close(true);
  }

  @override
  void dispose() {
    _request.cancel();
    _mobile.dispose();
    _nationCode.dispose();
    _cardNumber.dispose();
    _expiry.dispose();
    _securityCode.dispose();
    super.dispose();
  }

  void _close(bool paid) {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _request.cancel();
    Navigator.of(context).pop(paid);
  }

  Widget _testCard(Copy c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text(c.t('checkout', 'card'), style: const TextStyle(color: gold))),
          OutlinedButton(
            onPressed: _waiting ? null : () {
              _cardNumber.text = '4242 4242 4242 4242';
              _expiry.text = '12 / 30';
              _securityCode.text = '123';
              setState(() => _error = '');
            },
            child: Text(c.t('checkout', 'fillCard')),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        key: const ValueKey('test-card-number'),
        controller: _cardNumber,
        enabled: !_waiting,
        keyboardType: TextInputType.number,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(labelText: c.t('checkout', 'cardNumber')),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('test-card-expiry'),
              controller: _expiry,
              enabled: !_waiting,
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                labelText: c.t('checkout', 'expiry'),
                hintText: 'MM / YY',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('test-card-security-code'),
              controller: _securityCode,
              enabled: !_waiting,
              keyboardType: TextInputType.number,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: c.t('checkout', 'securityCode')),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(c.t('checkout', 'cardHint'), style: const TextStyle(fontSize: 12)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final c = _copy;
    final payso = widget.report.paysoTest;
    final orderOnly = widget.report.orderOnly;
    return AlertDialog(
      title: Text(c.t('checkout', _paid ? (payso || orderOnly ? 'success' : 'demoSuccess') :
          orderOnly && _order != null ? 'orderCreated' : 'title')),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.report.priceLabel,
            style: const TextStyle(color: gold, fontSize: 24),
          ),
          const SizedBox(height: 8),
          if (_order case final order?) ...[
            Text(
              '${c.t('checkout', orderOnly ? 'localOrder' : 'order')} · '
              '${payso ? order.reference : int.parse(order.reference).toString().padLeft(4, '0')}',
              style: const TextStyle(color: lavender, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (orderOnly && !_paid) ...[
              Text(c.t('checkout', 'pendingOrder'), style: const TextStyle(color: gold)),
              const SizedBox(height: 8),
              SelectableText('${c.t('checkout', 'gatewayOrder')} · ${order.gatewayOrder}'),
              const SizedBox(height: 8),
            ],
          ],
          if (_paid)
            Semantics(
              liveRegion: true,
              child: Text(c.t('checkout', 'successHint')),
            )
          else
            Text(c.t('checkout', orderOnly
                ? (_order == null ? 'orderOnlyHint' : _order!.checkoutUrl.isEmpty
                    ? 'cashierUnavailable' : 'cashierPreviewHint')
                : payso ? 'paysoHint' : 'demoHint')),
          if (orderOnly && _existingChecked && _order == null && _canRetry) ...[
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('order-nation-code'),
              controller: _nationCode,
              enabled: !_preparing,
              keyboardType: TextInputType.phone,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: c.t('checkout', 'nationCode'), prefixText: '+',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('order-mobile'),
              controller: _mobile,
              enabled: !_preparing,
              keyboardType: TextInputType.phone,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: c.t('checkout', 'mobile')),
            ),
          ],
          if (!_paid && !payso && !orderOnly && _order != null) ...[
            const SizedBox(height: 16),
            _testCard(c),
          ],
          if (!_paid && (_preparing || _waiting))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  c.t(
                    'checkout',
                    _preparing
                        ? (orderOnly && !_existingChecked ? 'loadingOrder' : 'preparing')
                        : payso || orderOnly
                        ? (orderOnly ? 'sunlandsWaiting' : 'paysoWaiting')
                        : 'confirming',
                  ),
                ),
              ),
            ),
          errorMessage(_error),
        ],
      ),
      actions: [
        if (_paid)
          FilledButton(
            onPressed: () => _close(true),
            child: Text(c.t('checkout', 'openReport')),
          )
        else ...[
          TextButton(
            onPressed: _waiting && !payso && !orderOnly ? null : () => _close(false),
            child: Text(c.t('checkout', orderOnly && _order == null && _canRetry
                ? 'cancelOrderEntry' : 'close')),
          ),
          if (orderOnly && _order != null)
            TextButton(
              onPressed: _waiting ? null : () => _startWaiting(immediately: true),
              child: Text(c.t('checkout', 'checkPayment')),
            ),
          if (orderOnly && _order != null && _order!.checkoutUrl.isNotEmpty)
            FilledButton(
              onPressed: _openSunlands,
              child: Text(c.t('checkout', 'openCashier')),
            )
          else if (_order != null && !orderOnly)
            FilledButton(
              onPressed: payso
                  ? _openPayso
                  : !_waiting
                  ? _simulatePayment
                  : null,
              child: Text(c.t('checkout', payso ? 'paysoOpen' : 'cardConfirm')),
            )
          else if (_order == null && !_preparing && _canRetry)
            FilledButton(
              onPressed: () => _prepare(existingOnly: orderOnly && !_existingChecked),
              child: Text(c.t('checkout', orderOnly && _existingChecked ? 'createOrderOnly' : 'retry')),
            ),
        ],
      ],
    );
  }
}
