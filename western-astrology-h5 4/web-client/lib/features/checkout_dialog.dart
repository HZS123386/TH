import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/controller.dart';
import '../core/models.dart';
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
    this.exportStatus = '',
    this.busy = false,
    this.error = '',
    this.showAppDownload = false,
    super.key,
  });
  final H5Controller h5;
  final LifeReport report;
  final VoidCallback onBack, onErase;
  final VoidCallback? onExportPdf;
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
                'assets/images/line-contact-qr.jpg',
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
                h5.browser.openPage('https://line.me/ti/p/DBMnHdX9sE');
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
              if (relationship) ...[
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
