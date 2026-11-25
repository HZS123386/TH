import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.onExportPdf,
    this.onPay,
    this.exportStatus = '',
    this.busy = false,
    this.error = '',
    this.showAppDownload = false,
    super.key,
  });
  final H5Controller h5;
  final LifeReport report;
  final VoidCallback onBack, onErase;
  final VoidCallback? onExportPdf, onPay;
  final String exportStatus;
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
  Widget _claimNumber(BuildContext context) {
    final copy = widget.h5.copy;
    final code = widget.report.claimCode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(copy.t('jy', 'lineContact.claimNumber')),
        const SizedBox(height: 4),
        SelectableText(
          code,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
            color: gold,
          ),
        ),
        TextButton(
          onPressed: () async {
            try {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(copy.t('jy', 'appLogin.copied'))),
                );
              }
            } on PlatformException {
              // The number remains selectable when clipboard access fails.
            }
          },
          child: Text(copy.t('jy', 'lineContact.copyReportId')),
        ),
      ],
    );
  }

  void _showLineContact() {
    final h5 = widget.h5;
    final reportId = widget.report.id;
    final copy = h5.copy;
    h5.trackActivity('preview_report', 'open_line_contact');
    var qrRecorded = false;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(copy.t('jy', 'lineContact.title')),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/line-contact-qr-956ed148.jpg',
                width: 232,
                height: 232,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, synchronous) {
                  if (!qrRecorded && (frame != null || synchronous)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (qrRecorded ||
                          !dialogContext.mounted ||
                          ModalRoute.isCurrentOf(dialogContext) != true) {
                        return;
                      }
                      qrRecorded = true;
                      h5.trackActivity('preview_report', 'line_qr_shown');
                      unawaited(h5.trackReport(reportId, 'line_contact'));
                    });
                  }
                  return child;
                },
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              Text(
                copy.t('jy', 'lineContact.scan'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _claimNumber(dialogContext),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(copy.t('jy', 'close')),
            ),
            FilledButton(
              onPressed: () {
                unawaited(h5.trackReport(reportId, 'line_contact'));
                h5.browser.openPage('https://line.me/ti/p/SmujXXCH9v');
              },
              child: Text(copy.t('jy', 'lineContact.open')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.h5.copy;
    final marriage = widget.report.marriageReport;
    final relationship = widget.report.sectionedReport;
    final themeHeading = c.t('jy', 'checkout.contents');
    final compactHeading = MediaQuery.sizeOf(context).width < 380;
    final hasRelationshipPreview = relationship
        ? widget.report.hasPreview
        : widget.report.relationshipPreview.isNotEmpty;
    final about = widget.report.sixPersonalThemes && hasRelationshipPreview
        ? 'checkout.relationshipAbout'
        : 'checkout.about';
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
              if (widget.report.relationshipReport) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: widget.onExportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                  label: Text(c.t('life', 'exportPdf')),
                ),
                if (widget.exportStatus.isNotEmpty)
                  Text(
                    widget.exportStatus,
                    style: const TextStyle(color: gold, fontSize: 12),
                  ),
              ],
              const SizedBox(height: 28),
              if (RegExp(
                r'^[1-9][0-9]{4}$',
              ).hasMatch(widget.report.claimCode)) ...[
                const SizedBox(height: 14),
                JYCard(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _claimNumber(context),
                      Text(
                        c.t('jy', 'lineContact.claimHint'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: lavender),
                      ),
                      const SizedBox(height: 12),
                      JYButton(
                        key: const ValueKey('jy-line-contact'),
                        label: c.t('jy', 'lineContact.action'),
                        onPressed: widget.busy ? null : _showLineContact,
                      ),
                    ],
                  ),
                ),
              ],
              if (!relationship) ...[
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
              ],
              JYCard(
                padding: EdgeInsets.symmetric(
                  horizontal: marriage ? 15 : 12,
                  vertical: marriage ? 20 : 16,
                ),
                radius: marriage ? 22 : 18,
                borderColor: const Color(0xFFDFB675),
                colors: const [Color(0xFF4C3263), Color(0xFF241732)],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!relationship || marriage) ...[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: marriage ? 12 : 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0x70E4BC78)),
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF67435C), Color(0xFF51335D)],
                          ),
                        ),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            fontSize: marriage
                                ? (compactHeading ? 17 : 19)
                                : 15,
                            height: marriage ? 1.4 : null,
                            color: const Color(0xFFFFE3AA),
                            fontWeight: FontWeight.w700,
                          ),
                          child: marriage
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const ExcludeSemantics(child: Text('✧')),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        themeHeading,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const ExcludeSemantics(child: Text('✧')),
                                  ],
                                )
                              : Text(
                                  '✧  $themeHeading  ✧',
                                  textAlign: TextAlign.center,
                                ),
                        ),
                      ),
                      SizedBox(height: marriage ? 20 : 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          for (final detail in c.list('jy', 'checkout.details'))
                            Text(
                              detail,
                              style: TextStyle(
                                color: gold,
                                fontSize: marriage ? 14 : 12,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: marriage ? 14 : 12),
                      ReportBadges(
                        key: const ValueKey('checkout-theme-badges'),
                        copy: c,
                        labelsInside: marriage,
                      ),
                    ],
                    if (widget.onPay != null) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0x40E4BC78)),
                      const SizedBox(height: 14),
                      Text(
                        widget.report.priceLabel,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.t('jy', 'checkout.preview'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      JYButton(
                        key: const ValueKey('jy-payment-preview'),
                        label: c.t(
                          'jy',
                          hasRelationshipPreview &&
                                  widget.report.sixPersonalThemes
                              ? 'personal.relationshipUnlock'
                              : 'checkout.pay',
                        ),
                        onPressed: widget.busy ? null : widget.onPay,
                      ),
                    ],
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
              if (!relationship) ...[
                const SizedBox(height: 18),
                JYCard(
                  padding: const EdgeInsets.fromLTRB(13, 17, 13, 15),
                  radius: 16,
                  borderColor: const Color(0x70E4BC78),
                  colors: const [Color(0xFF624162), Color(0xFF261733)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final line in c.list('jy', '${about}Title'))
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
                          c.t('jy', about),
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
              ],
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

const _paymentOptions = {
  'FM_ANTOM_LINEPAY': (name: 'LINE Pay', icon: 'payment-line-pay.webp'),
  'FM_PAYPAL': (name: 'PayPal', icon: 'payment-paypal.webp'),
  'FM_ANTOM_PIX': (name: 'Pix', icon: 'payment-pix.webp'),
  'FM_ANTOM_PAGALEVE': (name: 'Pagaleve', icon: 'payment-pagaleve.webp'),
  'FM_ANTOM_MERCADOPAGO_BR': (
    name: 'Mercado Pago',
    icon: 'payment-mercado-pago.webp',
  ),
};

class ReportPaymentDialog extends StatefulWidget {
  const ReportPaymentDialog({
    required this.h5,
    required this.report,
    this.returning = false,
    super.key,
  });

  static const pendingReportKey = 'fate-pending-checkout-report';
  final H5Controller h5;
  final LifeReport report;
  final bool returning;

  @override
  State<ReportPaymentDialog> createState() => _ReportPaymentDialogState();
}

class _ReportPaymentDialogState extends State<ReportPaymentDialog> {
  final _request = CancelToken();
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _securityCode = TextEditingController();
  PaymentOrder? _order;
  bool _preparing = false, _waiting = false, _paid = false;
  bool _canRetry = true;
  bool _loadingMethods = false, _openingMethod = false, _launchFailed = false;
  List<String>? _methods;
  String? _selectedMethod;
  String? _paypalUrl;
  String _error = '';

  Copy get _copy => widget.h5.reportCopy(widget.report);

  @override
  void initState() {
    super.initState();
    widget.h5.trackActivity('payment', 'open_payment');
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    if (_preparing || _request.cancelled || !_canRetry) return;
    final returning = widget.returning;
    setState(() {
      _preparing = true;
      _error = '';
      _canRetry = true;
    });
    final repository = widget.h5.repository;
    if (!returning) widget.h5.trackActivity('payment', 'create_order');
    try {
      try {
        // Returning from the cashier only reads and checks the saved order.
        final order = returning
            ? await repository.existingPayment(widget.report, _request)
            : await repository.createPayment(widget.report, _request);
        if (!mounted || _request.cancelled) return;
        if (returning && order == null) {
          _close(false);
          return;
        }
        if (!returning) widget.h5.trackActivity('payment', 'order_created');
        setState(() => _order = order);
        if (widget.report.orderOnly && order != null) {
          if (returning) {
            _startWaiting(immediately: true);
          } else {
            await _loadMethods();
          }
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

  Future<void> _loadMethods() async {
    if (_loadingMethods || _request.cancelled) return;
    setState(() {
      _loadingMethods = true;
      _methods = null;
      _selectedMethod = null;
      _launchFailed = false;
      _error = '';
    });
    try {
      final checkout = await widget.h5.repository.paymentMethods(
        widget.report,
        _request,
      );
      if (!mounted || _request.cancelled) return;
      setState(() {
        _methods = checkout.methods.where(_paymentOptions.containsKey).toList();
      });
      if (checkout.checkPayment) _startWaiting(immediately: true);
    } catch (error) {
      if (mounted && !_request.cancelled) {
        setState(() => _error = widget.h5.message(error, labels: _copy));
      }
    } finally {
      if (mounted && !_request.cancelled) {
        setState(() => _loadingMethods = false);
      }
    }
  }

  Future<void> _startSelectedMethod() async {
    final method = _selectedMethod;
    if (method == null || _openingMethod || _waiting || _paid) return;
    setState(() {
      _openingMethod = true;
      _error = '';
    });
    try {
      final url = await widget.h5.repository.startPayment(
        widget.report,
        method,
        _request,
      );
      if (!mounted || _request.cancelled) return;
      if (url == null) {
        _startWaiting(immediately: true);
      } else if (method == 'FM_PAYPAL') {
        // Open the new tab from a direct tap so browsers allow it.
        setState(() => _paypalUrl = url);
      } else {
        _openSunlands(url);
      }
    } catch (error) {
      if (mounted && !_request.cancelled) {
        widget.h5.trackActivity('payment', 'cashier_failed');
        final code = error is ApiFailure ? error.code : '';
        setState(() {
          _launchFailed =
              code != 'life_checkout_channel_link_missing' &&
              code != 'life_checkout_return_unavailable';
          if (code == 'life_checkout_unavailable') _methods = null;
          if (!_launchFailed) _selectedMethod = null;
          _error = widget.h5.message(error, labels: _copy);
        });
      }
    } finally {
      if (mounted && !_request.cancelled) {
        setState(() => _openingMethod = false);
      }
    }
  }

  void _openSunlands(String url, {bool sameTab = true}) {
    try {
      final browser = widget.h5.browser;
      browser.writeSetting(
        ReportPaymentDialog.pendingReportKey,
        widget.report.id,
        session: true,
      );
      widget.h5.trackActivity('payment', 'open_cashier');
      browser.openPage(url, sameTab: sameTab);
    } catch (error) {
      widget.h5.trackActivity('payment', 'cashier_failed');
      setState(() {
        _launchFailed = true;
        _error = widget.h5.message(error, labels: _copy);
      });
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

  void _selectMethod(String? method) {
    if (method == null || _openingMethod) return;
    setState(() {
      _selectedMethod = method;
      if (!_launchFailed) _error = '';
    });
  }

  Widget _methodTile(String code) {
    final option = _paymentOptions[code]!;
    final selected = code == _selectedMethod;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(11),
      side: BorderSide(color: selected ? gold : const Color(0xFF665073)),
    );
    return MergeSemantics(
      child: Material(
        color: selected ? const Color(0xFF493752) : const Color(0xFF241732),
        shape: shape,
        child: InkWell(
          key: ValueKey('payment-method-$code'),
          customBorder: shape,
          canRequestFocus: false,
          excludeFromSemantics: true,
          onTap: _openingMethod ? null : () => _selectMethod(code),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 5, 8, 5),
              child: Row(
                children: [
                  Radio<String>(
                    value: code,
                    enabled: !_openingMethod,
                    activeColor: gold,
                    visualDensity: const VisualDensity(horizontal: -4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Image.asset(
                      'assets/images/${option.icon}',
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      option.name,
                      style: const TextStyle(fontSize: 13, height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sunlandsPage() {
    final c = _copy;
    final order = _order;
    final paypalUrl = _paypalUrl;
    final methods = _methods ?? const <String>[];
    final busy = _preparing || _loadingMethods || _openingMethod || _waiting;
    final showMethods =
        paypalUrl == null && methods.isNotEmpty && !_waiting && !_paid;
    final amount = widget.report.price['amount'] as num;
    String? status;
    if (_waiting) {
      status = c.t('checkout', 'sunlandsWaiting');
    } else if (_openingMethod) {
      status = c.t('checkout', 'openingMethod');
    } else if (_loadingMethods) {
      status = c.t('checkout', 'loadingMethods');
    } else if (_preparing) {
      status = c.t('checkout', widget.returning ? 'loadingOrder' : 'preparing');
    }
    return Scaffold(
      key: const ValueKey('sunlands-payment-page'),
      appBar: AppBar(
        leading: IconButton(
          tooltip: c.t('checkout', 'close'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _close(_paid),
        ),
        title: const FateBrand(compact: true),
      ),
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.65, -.85),
              radius: 1.45,
              colors: [Color(0xFF392353), Color(0xFF160D29), Color(0xFF0C0816)],
            ),
          ),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: h5PortraitMaxWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      JYCard(
                        padding: const EdgeInsets.all(14),
                        radius: 14,
                        borderColor: const Color(0xFF876B86),
                        colors: const [Color(0xFF4C3263), Color(0xFF241732)],
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.t('checkout', 'reportProduct'),
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  c.t('checkout', 'once'),
                                  style: const TextStyle(color: lavender),
                                ),
                              ],
                            ),
                            const Divider(height: 22, color: Color(0xFF8C6E89)),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.t('checkout', 'totalDue'),
                                    style: const TextStyle(color: lavender),
                                  ),
                                ),
                                Text(
                                  '฿${(amount / 100).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: gold,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 19),
                      if (paypalUrl == null || _paid)
                        Semantics(
                          header: true,
                          child: Text(
                            c.t('checkout', _paid ? 'success' : 'openCashier'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      if (_paid) ...[
                        Text(c.t('checkout', 'successHint')),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => _close(true),
                          child: Text(c.t('checkout', 'openReport')),
                        ),
                      ],
                      if (showMethods) ...[
                        RadioGroup<String>(
                          groupValue: _selectedMethod,
                          onChanged: _selectMethod,
                          child: LayoutBuilder(
                            builder: (_, constraints) => Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final method in methods)
                                  SizedBox(
                                    width: (constraints.maxWidth - 8) / 2,
                                    child: _methodTile(method),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 13),
                        FilledButton(
                          key: const ValueKey('continue-payment'),
                          onPressed:
                              busy || _selectedMethod == null || _launchFailed
                              ? null
                              : _startSelectedMethod,
                          child: Text(c.t('checkout', 'continuePayment')),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          c.t('checkout', 'entryHint'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: lavender),
                        ),
                      ],
                      if (paypalUrl != null && !_paid) ...[
                        FilledButton(
                          key: const ValueKey('open-paypal'),
                          onPressed: _waiting
                              ? null
                              : () => _openSunlands(paypalUrl, sameTab: false),
                          child: Text(c.t('checkout', 'openPayPal')),
                        ),
                        const SizedBox(height: 7),
                        Text(c.t('checkout', 'payPalReturnHint')),
                        TextButton(
                          onPressed: () => _openSunlands(paypalUrl),
                          child: Text(c.t('checkout', 'openPayPalHere')),
                        ),
                      ],
                      if (status != null && !_paid)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(status),
                          ),
                        ),
                      if ((widget.returning || paypalUrl != null) &&
                          order != null &&
                          !_paid) ...[
                        Text(c.t('checkout', 'pendingOrder')),
                        SelectableText(
                          '${c.t('checkout', 'gatewayOrder')} · ${order.gatewayOrder}',
                          style: const TextStyle(color: lavender, fontSize: 12),
                        ),
                      ],
                      if (!widget.returning &&
                          paypalUrl == null &&
                          !busy &&
                          !_paid &&
                          _error.isEmpty &&
                          !showMethods)
                        Text(c.t('checkout', 'noMethods')),
                      errorMessage(_error),
                      if (!busy && !_paid)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            if (order == null && _canRetry && _error.isNotEmpty)
                              TextButton(
                                onPressed: _prepare,
                                child: Text(c.t('checkout', 'retry')),
                              ),
                            if (order != null &&
                                !widget.returning &&
                                paypalUrl == null &&
                                (!showMethods || _launchFailed))
                              TextButton(
                                onPressed: _loadMethods,
                                child: Text(c.t('checkout', 'retry')),
                              ),
                            if (order != null &&
                                (widget.returning ||
                                    !showMethods ||
                                    _launchFailed))
                              TextButton(
                                onPressed: () {
                                  widget.h5.trackActivity(
                                    'payment',
                                    'check_payment',
                                  );
                                  _startWaiting(immediately: true);
                                },
                                child: Text(c.t('checkout', 'checkPayment')),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (widget.report.orderOnly) return _sunlandsPage();
    final c = _copy;
    final payso = widget.report.paysoTest;
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
        c.t('checkout', _paid ? (payso ? 'success' : 'demoSuccess') : 'title'),
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
              Text(
                '${c.t('checkout', 'order')} · '
                '${payso ? order.reference : int.parse(order.reference).toString().padLeft(4, '0')}',
                style: const TextStyle(color: lavender, fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
            if (_paid)
              Semantics(
                liveRegion: true,
                child: Text(c.t('checkout', 'successHint')),
              )
            else
              Text(c.t('checkout', payso ? 'paysoHint' : 'demoHint')),
            if (!_paid && !payso && _order != null) ...[
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
                          ? 'preparing'
                          : payso
                          ? 'paysoWaiting'
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
                if (_order != null)
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
                    onPressed: _prepare,
                    child: Text(c.t('checkout', 'retry')),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _waiting && !payso
                          ? null
                          : () => _close(false),
                      style: TextButton.styleFrom(foregroundColor: lavender),
                      child: Text(c.t('checkout', 'close')),
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
