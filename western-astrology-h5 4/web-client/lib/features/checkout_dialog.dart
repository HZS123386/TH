import 'dart:async';

import 'package:flutter/material.dart';

import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';
import 'phone_country_picker.dart';
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
    this.showAppDownload = false,
    super.key,
  });
  final H5Controller h5;
  final LifeReport report;
  final VoidCallback onBack, onErase;
  final VoidCallback? onPay;
  final Widget freePreview;
  final bool busy;
  final String error;
  // Keep the download flow available for when the APP is ready to be shown again.
  final bool showAppDownload;

  Future<void> _showAppTestingNotice(BuildContext context) {
    final c = h5.copy;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('app-testing-dialog'),
        backgroundColor: panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line),
        ),
        title: Text(
          c.t('jy', 'checkout.appTestingTitle'),
          style: const TextStyle(
            color: cream,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          c.t('jy', 'checkout.appTestingMessage'),
          style: const TextStyle(color: lavender, fontSize: 14, height: 1.7),
        ),
        actions: [
          FilledButton(
            key: const ValueKey('app-testing-close'),
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(c.t('jy', 'checkout.appTestingClose')),
          ),
        ],
      ),
    );
  }

  @override
  State<ReportCheckout> createState() => _ReportCheckoutState();
}

class _ReportCheckoutState extends State<ReportCheckout> {
  @override
  Widget build(BuildContext context) {
    final c = widget.h5.copy;
    final relationship = widget.report.relationshipReport;
    final hasRelationshipPreview = widget.report.relationshipPreview.isNotEmpty;
    final about = widget.report.sixPersonalThemes && hasRelationshipPreview
        ? 'checkout.relationshipAbout'
        : 'checkout.about';
    final relationshipUnlock = widget.report.canPay && hasRelationshipPreview
        ? (relationship
              ? c.t('relationship', 'unlock')
              : c.t('jy', 'personal.relationshipUnlock'))
        : '';
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
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('report-back-home'),
                    tooltip: c.t('jy', 'checkout.back'),
                    onPressed: widget.busy ? null : widget.onBack,
                    icon: const Icon(Icons.arrow_back, color: gold, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const FateBrand(compact: true),
                ],
              ),
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
                relationship
                    ? text(widget.report.json['title'])
                    : c.t('jy', 'checkout.title'),
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
                    if (!relationship)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          for (final detail in c.list('jy', 'checkout.details'))
                            Text(
                              detail,
                              style: const TextStyle(color: gold, fontSize: 12),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    ReportBadges(
                      key: const ValueKey('checkout-theme-badges'),
                      copy: c,
                      themes: relationship
                          ? [
                              for (final item in widget.report.catalog)
                                {'key': item['key'], c.language: item['title']},
                            ]
                          : null,
                    ),
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
                      label: relationshipUnlock.isNotEmpty
                          ? relationshipUnlock
                          : widget.report.orderOnly
                          ? c.t('checkout', 'title')
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
                              widget.report.orderOnly
                                  ? 'entryHint'
                                  : widget.report.paysoTest
                                  ? 'payso'
                                  : 'demoHint',
                            )
                          : c.t('jy', 'checkout.preview'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: lavender),
                    ),
                    if (widget.showAppDownload) ...[
                      const SizedBox(height: 14),
                      JYButton(
                        key: const ValueKey('jy-app-download'),
                        label: c.t('jy', 'checkout.download'),
                        icon: 'download',
                        pulse: true,
                        onPressed: widget.busy
                            ? null
                            : () => widget._showAppTestingNotice(context),
                      ),
                    ],
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
                    for (final line
                        in relationship
                            ? [c.t('relationship', 'sections.who')]
                            : c.list('jy', '${about}Title'))
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
                        relationship
                            ? c.t('relationship', 'checkout')
                            : c.t('jy', about),
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
  late final _countries = objects(
    widget.h5.translations['phoneCountries'],
  ).map(PhoneCountry.new).toList();
  late PhoneCountry _country = _countries.firstWhere(
    (item) => item.iso2 == 'TH',
  );
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
    widget.h5.trackActivity('payment', 'open_payment');
    unawaited(_prepare(existingOnly: widget.report.orderOnly));
  }

  Future<void> _prepare({bool existingOnly = false}) async {
    if (_preparing || _request.cancelled || !_canRetry) return;
    final mobile = _mobile.text.trim().replaceAll(RegExp(r'[ \t()-]'), '');
    final nationCode = _country.dialCode;
    if (widget.report.orderOnly &&
        !existingOnly &&
        (!RegExp(r'^[0-9]{6,14}$').hasMatch(mobile) ||
            !RegExp(r'^[1-9][0-9]{0,2}$').hasMatch(nationCode) ||
            mobile.length + nationCode.length > 15)) {
      setState(() => _error = _copy.t('checkout', 'life_order_phone_invalid'));
      widget.h5.trackActivity('payment', 'invalid_phone');
      return;
    }
    setState(() {
      _preparing = true;
      _error = '';
      _canRetry = true;
    });
    final repository = widget.h5.repository;
    if (!existingOnly) widget.h5.trackActivity('payment', 'create_order');
    try {
      try {
        // Reopening reads the saved order; only the explicit create button can submit one.
        final order = existingOnly
            ? await repository.existingPayment(widget.report, _request)
            : await repository.createPayment(
                widget.report,
                _request,
                mobile: mobile,
                nationCode: nationCode,
              );
        if (mounted) {
          if (!existingOnly) {
            widget.h5.trackActivity('payment', 'order_created');
          }
          setState(() {
            _order = order;
            if (existingOnly) _existingChecked = true;
          });
        }
        if (mounted && widget.report.orderOnly && order != null) {
          _startWaiting();
        }
      } on ApiFailure catch (error) {
        if (widget.report.orderOnly ||
            error.status != 409 ||
            !await repository.checkPayment(widget.report, _request)) {
          rethrow;
        }
        if (mounted) {
          await _showSuccess();
        }
      }
    } catch (error) {
      if (mounted && !_request.cancelled) {
        widget.h5.trackActivity('payment', 'order_failed');
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
          if (existingOnly && code == 'life_order_access_denied') {
            _existingChecked = true;
          }
          _canRetry =
              !widget.report.orderOnly ||
              (code != 'life_order_needs_review' &&
                  code != 'life_order_rejected' &&
                  code != 'life_order_channel_invalid');
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
      widget.h5.trackActivity('payment', 'open_cashier');
    } catch (error) {
      widget.h5.trackActivity('payment', 'cashier_failed');
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
      widget.h5.trackActivity('payment', 'open_cashier');
    } catch (error) {
      widget.h5.trackActivity('payment', 'cashier_failed');
      setState(() => _error = widget.h5.message(error, labels: _copy));
      return;
    }
    _startWaiting();
  }

  void _startWaiting({bool immediately = false}) {
    if (_waiting || _paid || _request.cancelled) return;
    if (immediately) widget.h5.trackActivity('payment', 'check_payment');
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
          if (error.status == 404 ||
              error.status == 409 ||
              error.code == 'life_payment_check_access_denied') {
            return;
          }
          final retryAfter = error.retryAfter;
          delay = retryAfter != null && retryAfter > interval
              ? retryAfter
              : interval;
        } catch (error) {
          if (error is Cancelled) rethrow;
          if (mounted) {
            setState(() => _error = widget.h5.message(error, labels: _copy));
          }
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
      if (mounted) {
        await _showSuccess();
      }
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
    widget.h5.trackActivity('payment', 'payment_result');
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
          Expanded(
            child: Text(
              c.t('checkout', 'card'),
              style: const TextStyle(color: gold),
            ),
          ),
          OutlinedButton(
            onPressed: _waiting
                ? null
                : () {
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
              decoration: InputDecoration(
                labelText: c.t('checkout', 'securityCode'),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(c.t('checkout', 'cardHint'), style: const TextStyle(fontSize: 12)),
    ],
  );

  Widget _phoneFields(Copy c) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final country = PhoneCountryPicker(
      key: const ValueKey('order-nation-code'),
      copy: c,
      countries: _countries,
      country: _country,
      showName: narrow,
      enabled: !_preparing,
      onChanged: (country) => setState(() => _country = country),
    );
    final mobile = TextField(
      key: const ValueKey('order-mobile'),
      controller: _mobile,
      enabled: !_preparing,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: c.t('checkout', 'mobile'),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: c.t('checkout', 'mobileHint'),
        hintStyle: const TextStyle(color: lavender, fontSize: 12),
      ),
    );
    return narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [country, const SizedBox(height: 12), mobile],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 116, child: country),
              const SizedBox(width: 12),
              Expanded(child: mobile),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy;
    final payso = widget.report.paysoTest;
    final orderOnly = widget.report.orderOnly;
    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: 440),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: line),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: cream,
        fontSize: 22,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: lavender,
        fontSize: 13,
        height: 1.6,
      ),
      title: Text(
        c.t(
          'checkout',
          _paid
              ? (payso || orderOnly ? 'success' : 'demoSuccess')
              : orderOnly && _order != null
              ? 'orderCreated'
              : 'title',
        ),
      ),
      scrollable: true,
      content: SizedBox(
        width: 392,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withValues(alpha: .25)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      c.t('checkout', 'once'),
                      style: const TextStyle(color: cream, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.report.priceLabel,
                    style: const TextStyle(
                      color: gold,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_order case final order?) ...[
              if (!orderOnly) ...[
                Text(
                  '${c.t('checkout', 'order')} · '
                  '${payso ? order.reference : int.parse(order.reference).toString().padLeft(4, '0')}',
                  style: const TextStyle(color: lavender, fontSize: 12),
                ),
                const SizedBox(height: 8),
              ],
              if (orderOnly && !_paid) ...[
                Text(
                  c.t('checkout', 'pendingOrder'),
                  style: const TextStyle(color: gold),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  '${c.t('checkout', 'gatewayOrder')} · ${order.gatewayOrder}',
                  style: const TextStyle(color: lavender, fontSize: 11),
                ),
                const SizedBox(height: 8),
              ],
            ],
            if (_paid)
              Semantics(
                liveRegion: true,
                child: Text(c.t('checkout', 'successHint')),
              )
            else
              Text(
                c.t(
                  'checkout',
                  orderOnly
                      ? (_order == null
                            ? 'orderOnlyHint'
                            : _order!.checkoutUrl.isEmpty
                            ? 'cashierUnavailable'
                            : 'cashierPreviewHint')
                      : payso
                      ? 'paysoHint'
                      : 'demoHint',
                ),
              ),
            if (orderOnly &&
                _existingChecked &&
                _order == null &&
                _canRetry) ...[
              const SizedBox(height: 20),
              _phoneFields(c),
              const SizedBox(height: 8),
              Text(
                c.t('checkout', 'phoneHint'),
                style: const TextStyle(
                  color: lavender,
                  fontSize: 11,
                  height: 1.5,
                ),
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
                          ? (orderOnly && !_existingChecked
                                ? 'loadingOrder'
                                : 'preparing')
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
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_paid)
                FilledButton(
                  onPressed: () => _close(true),
                  child: Text(c.t('checkout', 'openReport')),
                )
              else ...[
                if (orderOnly &&
                    _order != null &&
                    _order!.checkoutUrl.isNotEmpty)
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
                    child: Text(
                      c.t('checkout', payso ? 'paysoOpen' : 'cardConfirm'),
                    ),
                  )
                else if (_order == null && !_preparing && _canRetry)
                  FilledButton(
                    onPressed: () =>
                        _prepare(existingOnly: orderOnly && !_existingChecked),
                    child: Text(
                      c.t(
                        'checkout',
                        orderOnly && _existingChecked
                            ? 'createOrderOnly'
                            : 'retry',
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _waiting && !payso && !orderOnly
                          ? null
                          : () => _close(false),
                      style: TextButton.styleFrom(foregroundColor: lavender),
                      child: Text(
                        c.t(
                          'checkout',
                          orderOnly && _order == null && _canRetry
                              ? 'cancelOrderEntry'
                              : 'close',
                        ),
                      ),
                    ),
                    if (orderOnly && _order != null)
                      TextButton(
                        onPressed: _waiting
                            ? null
                            : () => _startWaiting(immediately: true),
                        child: Text(c.t('checkout', 'checkPayment')),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
