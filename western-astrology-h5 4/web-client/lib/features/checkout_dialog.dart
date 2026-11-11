import 'package:flutter/material.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../ui/theme.dart';
import '../ui/jy_components.dart';

class ReportCheckout extends StatelessWidget {
  const ReportCheckout({
    required this.h5,
    required this.report,
    required this.onBack,
    required this.onErase,
    required this.onUnlock,
    this.busy = false,
    this.error = '',
    super.key,
  });
  final H5Controller h5;
  final LifeReport report;
  final VoidCallback onBack, onErase, onUnlock;
  final bool busy;
  final String error;
  @override
  Widget build(BuildContext context) {
    final c = h5.copy;
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
              const SizedBox(height: 14),
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
                        const Text(
                          '฿39',
                          style: TextStyle(
                            fontSize: 27,
                            color: Color(0xFFF7D69E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    JYButton(
                      key: const ValueKey('jy-unlock-report'),
                      label: c.t('jy', 'checkout.pay'),
                      icon: 'lock',
                      onPressed: busy ? null : onUnlock,
                      dimDisabled: false,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      c.t('jy', 'checkout.preview'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: lavender),
                    ),
                    const SizedBox(height: 14),
                    JYButton(
                      key: const ValueKey('jy-app-download'),
                      label: c.t('jy', 'checkout.download'),
                      icon: 'download',
                      pulse: true,
                      onPressed: busy ? null : onUnlock,
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
                    onPressed: busy ? null : onBack,
                    child: Text(c.t('jy', 'checkout.back')),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : onErase,
                    child: Text(c.t('jy', 'erase')),
                  ),
                ],
              ),
              errorMessage(error),
            ],
          ),
        ),
      ),
    );
  }
}
