import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../purchases/purchase_sheet.dart';
import 'reports_view_model.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({this.detail = false, this.example = false, super.key});
  final bool detail, example;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  ReportsViewModel? model;
  bool exampleExpanded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (model != null) return;
    model = DependencyScope.of(context).reports;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      model!.setActive(widget.detail && !widget.example, view: this);
      if (!widget.detail) model!.loadHistory();
      if (widget.detail && !widget.example && model!.reference == null) {
        model!.resume();
      }
    });
  }

  Future<void> generate() async {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    if (d.session.profile == null) {
      context.go('/birth');
      return;
    }
    if (d.chart.result == null) {
      context.go('/chart');
      await d.chart.calculate();
      return;
    }
    final noticeVersion = d.session.capabilities.aiNoticeVersion;
    if (!d.session.capabilities.reports || noticeVersion == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.serviceSetup)));
      return;
    }
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(s.aiConsent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.decline),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.consentGenerate),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;
    try {
      await d.session.configuration.consent(noticeVersion);
      await d.reports.generate(d.chart.result!);
      if (mounted) context.go('/reports/reading');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([d.reports, d.session]),
      builder: (context, _) {
        final report = d.reports.report,
            full = widget.example ? exampleExpanded : report?.full == true;
        void unlock() => showPurchaseSheet(
          context,
          reportId: report?.id,
          previewExample: widget.example
              ? () => setState(() => exampleExpanded = true)
              : null,
        );
        if (!widget.detail) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeading(s.reports, s.reportIntro),
                FateCard(
                  gold: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.free,
                        style: const TextStyle(color: goldColor, fontSize: 11),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        s.reportTitle,
                        style: const TextStyle(fontSize: 24, height: 1.6),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.homeReportText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(),
                      Wrap(
                        spacing: 15,
                        runSpacing: 12,
                        children:
                            [
                                  s.chapterPersonality,
                                  s.chapterLove,
                                  s.chapterWork,
                                  s.chapterMoney,
                                ]
                                .map(
                                  (label) => Text(
                                    '✧ $label',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: mutedColor,
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: d.reports.loading ? null : generate,
                        child: Text(
                          d.reports.loading ? s.reportPending : s.generate,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.go('/reports/reading?example=1'),
                        child: Text(s.exampleReport),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (d.reports.hasResumable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: OutlinedButton(
                      onPressed: () {
                        d.reports.resume();
                        context.go('/reports/reading');
                      },
                      child: Text(s.resumeReport),
                    ),
                  ),
                if (d.reports.history.isNotEmpty) ...[
                  Text(s.personalReport, style: const TextStyle(fontSize: 17)),
                  for (final reference in d.reports.history)
                    ListTile(
                      title: Text(s.reportTitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        d.reports.resume(reference);
                        context.go('/reports/reading');
                      },
                    ),
                ],
                FateCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.savedReports,
                        style: const TextStyle(fontSize: 17),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.exampleSavedNote,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      if (d.reports.exampleSaved)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.exampleBadge),
                          trailing: IconButton(
                            tooltip: s.remove,
                            onPressed: d.reports.removeExample,
                            icon: const Icon(Icons.delete_outline),
                          ),
                          onTap: () => context.go('/reports/reading?example=1'),
                        )
                      else
                        Text(
                          s.reportEmpty,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        if (!widget.example && report == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (d.reports.loading) const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(d.reports.loading ? s.reportPending : s.reportEmpty),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: d.reports.loading
                        ? null
                        : () => d.reports.resume(),
                    child: Text(s.resumeReport),
                  ),
                  TextButton(
                    onPressed: () => context.go('/reports/reading?example=1'),
                    child: Text(s.exampleReport),
                  ),
                ],
              ),
            ),
          );
        }
        if (!widget.example && (report!.generating || report.failed)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (report.generating) const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    report.generating ? s.reportPending : s.reportFailedText,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (report.generating)
                    Text(
                      s.reportGeneratingText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  TextButton(
                    onPressed: () => context.go('/reports'),
                    child: Text(s.reports),
                  ),
                ],
              ),
            ),
          );
        }
        return Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.go('/reports'),
                        icon: const Icon(Icons.arrow_back, size: 17),
                        label: Text(s.reports),
                      ),
                    ),
                    if (widget.example)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: FateCard(
                          child: Text(
                            '${s.exampleBadge}\n${s.exampleNote}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    FateCard(
                      gold: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'FATE · ${s.system}',
                                  style: const TextStyle(
                                    color: goldColor,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              if (widget.example)
                                TextButton(
                                  onPressed: d.reports.saveExample,
                                  child: Text(
                                    d.reports.exampleSaved
                                        ? s.reportSaved
                                        : s.saveReport,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            s.reportTitle,
                            style: const TextStyle(fontSize: 25, height: 1.6),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            s.reportIntro,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 24),
                          if (report?.developmentPreview == true) ...[
                            Text(
                              s.developmentReport,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 20),
                          ],
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: goldColor.withValues(alpha: .35),
                              ),
                              color: goldColor.withValues(alpha: .07),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.summary,
                                  style: const TextStyle(
                                    color: goldColor,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  widget.example
                                      ? s.sampleSummary
                                      : report!.summary,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.85,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          Text(
                            s.traits,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (widget.example) ...[
                            ReadingParagraph(
                              s.sampleTrait1Title,
                              s.sampleTrait1Text,
                            ),
                            ReadingParagraph(
                              s.sampleTrait2Title,
                              s.sampleTrait2Text,
                            ),
                          ] else
                            for (final section in report!.preview)
                              ReadingParagraph(
                                section.title,
                                section.paragraphs.join('\n\n'),
                              ),
                          const Divider(),
                          Text(
                            widget.example ? s.watch : s.fullReading,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (full)
                            if (widget.example)
                              _ExampleReading(s: s)
                            else ...[
                              if (report!.generating) Text(s.reportPending),
                              for (final section in report.sections)
                                ReadingParagraph(
                                  section.title,
                                  section.paragraphs.join('\n\n'),
                                ),
                            ]
                          else
                            Stack(
                              children: [
                                ExcludeSemantics(
                                  child: IgnorePointer(
                                    child: ImageFiltered(
                                      imageFilter: ImageFilter.blur(
                                        sigmaX: 6,
                                        sigmaY: 6,
                                      ),
                                      child: widget.example
                                          ? _ExampleReading(s: s)
                                          : const _LockedLines(),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 45,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 28,
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        colors: [
                                          panelColor,
                                          panelColor.withValues(alpha: .85),
                                          panelColor.withValues(alpha: 0),
                                        ],
                                        radius: 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            color: panelColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: goldColor.withValues(
                                                alpha: .7,
                                              ),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.lock_outline,
                                            size: 27,
                                            color: goldColor,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                          s.lockedTitle,
                                          style: const TextStyle(fontSize: 17),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          s.lockedText,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 20),
                                        OutlinedButton(
                                          onPressed: unlock,
                                          child: Text(s.unlock),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (d.reports.error != null)
                            Text(
                              s.error,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!full)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: const BoxDecoration(
                    color: panelColor,
                    border: Border(top: BorderSide(color: lineColor)),
                  ),
                  child: FilledButton.icon(
                    key: const ValueKey('unlock-report'),
                    onPressed: unlock,
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: Text('${s.unlock}  →'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    model?.setActive(false, view: this);
    super.dispose();
  }
}

class _LockedLines extends StatelessWidget {
  const _LockedLines();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < 5; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 17,
                width: 180,
                color: mutedColor.withValues(alpha: .2),
              ),
              const SizedBox(height: 14),
              for (var j = 0; j < 4; j++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    height: 12,
                    color: mutedColor.withValues(alpha: .12),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

class _ExampleReading extends StatelessWidget {
  const _ExampleReading({required this.s});
  final AppLocalizations s;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ReadingParagraph(s.sampleWatch1Title, s.sampleWatch1Text),
      ReadingParagraph(s.sampleWatch2Title, s.sampleWatch2Text),
      const Divider(),
      Text(
        s.advice,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 24),
      for (final row in [
        (s.sampleAdvice1Title, s.sampleAdvice1Text),
        (s.sampleAdvice2Title, s.sampleAdvice2Text),
        (s.sampleAdvice3Title, s.sampleAdvice3Text),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FateCard(child: ReadingParagraph(row.$1, row.$2)),
        ),
      for (final row in [
        (s.chapterLove, s.sampleLoveText, s.sampleLoveAction),
        (s.chapterWork, s.sampleWorkText, s.sampleWorkAction),
        (s.chapterMoney, s.sampleMoneyText, s.sampleMoneyAction),
      ]) ...[
        const Divider(),
        ReadingParagraph(row.$1, row.$2),
        FateCard(child: ReadingParagraph(s.advice, row.$3)),
      ],
    ],
  );
}
