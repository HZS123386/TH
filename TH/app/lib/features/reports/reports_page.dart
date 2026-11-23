import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/dependencies.dart';
import '../../data/reports_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../purchases/purchase_sheet.dart';
import '../companion/guardian.dart';
import 'reports_view_model.dart';
import 'content_report_sheet.dart';
import '../../core/models/calculation.dart';
import '../../core/models/report.dart';
import '../../ui/strings.dart';
import '../chart/chart_wheel.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    this.detail = false,
    this.fromChart = false,
    this.example = false,
    this.backLocation = '/reports',
    super.key,
  });
  final String backLocation;
  final bool detail, example, fromChart;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  ReportsViewModel? model;
  bool exampleExpanded = false;
  bool opening = false, movingToProgress = false;
  String? openedScope;
  final sectionKeys = <String, GlobalKey>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (model != null) return;
    model = DependencyScope.of(context).reports;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      model!.setActive(widget.detail && !widget.example, view: this);
      if (!widget.detail) {
        model!.loadHistory();
        model!.setH5HistoryView(this, active: true);
      }
    });
  }

  Future<void> openReading() async {
    final d = DependencyScope.of(context), scope = d.session.scope;
    bool current() => mounted && scope == d.session.scope;
    setState(() => opening = true);
    try {
      if (!widget.fromChart) {
        if (d.reports.reference == null) await d.reports.resume();
        return;
      }
      if (d.session.profile?.isServerRevision != true) {
        context.go('/birth');
        return;
      }
      if (d.chart.loading) {
        openedScope = null;
        return;
      }
      if (d.chart.result == null) await d.chart.calculate();
      if (!current() || d.chart.result == null) return;
      final calculation = d.chart.result!;
      bool matches(ReportReference? ref) =>
          ref?.resultId == calculation.id &&
          ref?.locale == d.session.locale.languageCode;
      if (matches(d.reports.reference)) return;
      final saved = d.reports.repository.active(d.session.owner);
      if (matches(saved)) {
        await d.reports.resume(saved);
        return;
      }
      await d.reports.loadHistory();
      if (!current()) return;
      final previous = d.reports.history.where(matches).firstOrNull;
      if (previous != null) {
        await d.reports.resume(previous);
      } else {
        await generate();
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
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
    final scope = d.session.scope, result = d.chart.result!;
    final consent = await showDialog<bool>(
      context: context,
      animationStyle: FateMotion.dialog(context),
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
    if (consent != true || !mounted || d.session.scope != scope) return;
    try {
      await d.session.configuration.consent(noticeVersion);
      if (d.session.scope != scope) return;
      await d.reports.generate(result);
      if (mounted && !widget.detail && d.session.scope == scope) {
        context.go('/reports/reading');
      }
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
      listenable: Listenable.merge([d.reports, d.chart, d.session]),
      builder: (context, _) {
        if (widget.detail &&
            !widget.example &&
            !d.session.loading &&
            (!widget.fromChart || !d.chart.loading) &&
            !opening &&
            openedScope != d.session.scope) {
          openedScope = d.session.scope;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) openReading();
          });
        }
        final report =
            widget.fromChart && d.reports.report?.resultId != d.chart.result?.id
            ? null
            : d.reports.report;
        final storeEnabled = d.purchases.storeEnabled;
        final full = widget.example
            ? !storeEnabled || exampleExpanded
            : report?.full == true;
        final showPaywall = !full && storeEnabled;
        if (report?.generating != true) movingToProgress = false;
        if (widget.detail &&
            widget.backLocation != '/reports' &&
            !widget.example &&
            report?.generating == true &&
            !movingToProgress) {
          movingToProgress = true;
          final current = GoRouterState.of(context).uri;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                d.reports.report?.id != report!.id ||
                d.reports.report?.generating != true) {
              return;
            }
            context.go(
              Uri(
                path: '/chart/generating',
                queryParameters: {
                  ...current.queryParameters,
                  'report': report.id,
                },
              ).toString(),
            );
          });
        }
        final failureText = switch (report?.failureReason) {
          'service_busy' => s.reportServiceBusy,
          'service_timeout' => s.reportServiceTimeout,
          _ => s.reportFailedText,
        };
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
                PageHeading(
                  s.reports,
                  s.reportIntro,
                  icon: Icons.menu_book_outlined,
                ),
                TextButton.icon(
                  key: const ValueKey('reports-saved-readings'),
                  onPressed: () => context.push('/chart/readings?from=reports'),
                  icon: const Icon(Icons.history),
                  label: Text(s.savedReadings),
                ),
                if (d.auth.hasH5Reports) ...[
                  _H5History(model: d.reports),
                  const SizedBox(height: 20),
                ],
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
                  Text(
                    opening || d.reports.loading
                        ? s.reportPending
                        : s.reportEmpty,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: opening || d.reports.loading ? null : generate,
                    child: Text(s.generate),
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
                    report.generating ? s.reportPending : failureText,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (report.generating)
                    Text(
                      s.reportGeneratingText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (report.failed)
                    FilledButton(
                      onPressed: d.reports.loading ? null : generate,
                      child: Text(s.generate),
                    ),
                  TextButton(
                    onPressed: () => context.go(widget.backLocation),
                    child: Text(s.reports),
                  ),
                ],
              ),
            ),
          );
        }
        final sections = [...?report?.preview, if (full) ...?report?.sections];
        GlobalKey sectionKey(String key) =>
            sectionKeys.putIfAbsent(key, GlobalKey.new);
        return FateEntrance(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  key: const ValueKey('reading-scroll'),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    showPaywall ? 100 : 28,
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.go(widget.backLocation),
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
                      if (sections.isNotEmpty) ...[
                        FateCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.readingContents,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s.readingContentsHint,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final section in sections)
                                    ActionChip(
                                      key: ValueKey(
                                        'reading-jump-${section.key}',
                                      ),
                                      label: Text(section.title),
                                      onPressed: () {
                                        final target = sectionKey(
                                          section.key,
                                        ).currentContext;
                                        if (target != null) {
                                          Scrollable.ensureVisible(
                                            target,
                                            alignment: .03,
                                            duration:
                                                MediaQuery.disableAnimationsOf(
                                                  context,
                                                )
                                                ? Duration.zero
                                                : const Duration(
                                                    milliseconds: 300,
                                                  ),
                                          );
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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
                            if (!widget.example) ...[
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: () => openGuardian(
                                  context,
                                  reading: ReadingHandoff(
                                    title: s.reportTitle,
                                    owner: d.session.owner,
                                    text: [
                                      report!.summary,
                                      ...report.preview.expand(
                                        (section) => section.paragraphs,
                                      ),
                                      if (report.full)
                                        ...report.sections.expand(
                                          (section) => section.paragraphs,
                                        ),
                                    ].join('\n\n'),
                                  ),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: Text(s.continueReading),
                              ),
                            ],
                            if (report?.number case final number?)
                              SelectableText(
                                '${s.reportNumberLabel} · $number',
                              ),
                            if (widget.example || report?.calculation != null)
                              _ReadingChart(
                                result: widget.example
                                    ? teachingChart
                                    : report!.calculation!,
                              ),
                            if (!widget.example)
                              TextButton.icon(
                                key: const ValueKey('chart-reading-history'),
                                onPressed: () {
                                  final location =
                                      widget.backLocation.startsWith(
                                        '/chart/readings',
                                      )
                                      ? widget.backLocation
                                      : widget.backLocation == '/reports'
                                      ? '/chart/readings?from=reports'
                                      : '/chart/readings';
                                  context.go(location);
                                },
                                icon: const Icon(Icons.history),
                                label: Text(s.savedReadings),
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
                                _ReadingSection(
                                  key: sectionKey(section.key),
                                  section: section,
                                  number: sections.indexOf(section) + 1,
                                ),
                            if (full || showPaywall) ...[
                              const Divider(),
                              Text(
                                widget.example ? s.watch : s.fullReading,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            if (full)
                              FateEntrance(
                                key: const ValueKey('unlocked-reading'),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (widget.example)
                                      _ExampleReading(s: s)
                                    else ...[
                                      if (report!.generating)
                                        Text(s.reportPending),
                                      for (final section in report.sections)
                                        _ReadingSection(
                                          key: sectionKey(section.key),
                                          section: section,
                                          number: sections.indexOf(section) + 1,
                                        ),
                                    ],
                                  ],
                                ),
                              )
                            else if (showPaywall)
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
                                            style: const TextStyle(
                                              fontSize: 17,
                                            ),
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
                            if (!widget.example)
                              TextButton.icon(
                                onPressed: () => showContentReport(
                                  context,
                                  kind: 'western_report',
                                  id: report!.id,
                                ),
                                icon: const Icon(Icons.flag_outlined, size: 17),
                                label: Text(s.contentReport),
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
              if (showPaywall)
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
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    model?.setActive(false, view: this);
    model?.setH5HistoryView(this, active: false);
    super.dispose();
  }
}

class _H5History extends StatelessWidget {
  const _H5History({required this.model});

  final ReportsViewModel model;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final dates = MaterialLocalizations.of(context);
    return FateCard(
      gold: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.h5Reports, style: const TextStyle(fontSize: 18)),
              ),
              IconButton(
                tooltip: s.h5Refresh,
                onPressed: model.h5Loading ? null : () => model.loadH5History(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (model.h5Loading) const LinearProgressIndicator(),
          if (model.h5Failed)
            Text(
              s.h5ReportUnavailable,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else if (!model.h5Loading && model.h5History.isEmpty)
            Text(
              s.h5ReportsEmpty,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          for (final report in model.h5History)
            ListTile(
              key: ValueKey('h5-report-${report.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                report.birthDate.isEmpty
                    ? s.reportTitle
                    : '${s.birthDate}  ${report.birthDate}',
              ),
              subtitle: Text(
                [
                  h5ReportStatusLabel(s, report.full, report.fullState),
                  if (report.createdAt case final date?) ...[
                    dates.formatCompactDate(date),
                    dates.formatTimeOfDay(TimeOfDay.fromDateTime(date)),
                  ],
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push('/reports/h5/${Uri.encodeComponent(report.id)}'),
            ),
          if (model.h5HasMore)
            TextButton(
              onPressed: model.h5Loading
                  ? null
                  : () => model.loadH5History(more: true),
              child: Text(s.h5LoadMore),
            ),
        ],
      ),
    );
  }
}

class _ReadingChart extends StatefulWidget {
  const _ReadingChart({required this.result});
  final CalculationSnapshot result;

  @override
  State<_ReadingChart> createState() => _ReadingChartState();
}

class _ReadingChartState extends State<_ReadingChart> {
  String selected = 'sun';

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), result = widget.result;
    final planet = result.planets.where((p) => p.key == selected).firstOrNull;
    return FateCard(
      key: const ValueKey('reading-chart'),
      gold: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.readingChart,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (result.estimatedTime) ...[
            const SizedBox(height: 8),
            Text(
              s.estimatedChart,
              style: const TextStyle(color: goldColor, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            s.readingChartIntro,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Semantics(
            label: s.readingChart,
            child: ChartWheel(
              result: result,
              selected: selected,
              onSelected: (key) => setState(() => selected = key),
            ),
          ),
          if (planet != null) ...[
            Center(
              child: Text(
                '${s.planetName(planet.key)} · ${s.position(planet.longitude)}${planet.estimated ? ' · ${s.estimated}' : ''}',
                style: const TextStyle(color: goldColor, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in [
                (
                  s.sun,
                  result.planets
                      .where((p) => p.key == 'sun')
                      .firstOrNull
                      ?.longitude,
                ),
                (
                  s.moon,
                  result.planets
                      .where((p) => p.key == 'moon')
                      .firstOrNull
                      ?.longitude,
                ),
                (s.ascendant, result.ascendant),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Text(
                          result.estimatedTime
                              ? '${row.$1} · ${s.estimated}'
                              : row.$1,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          row.$2 == null
                              ? '—'
                              : s.zodiacNames[(row.$2! / 30).floor()],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: goldColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (!result.exactTime ||
              result.ascendant == null ||
              result.houses.isEmpty) ...[
            const SizedBox(height: 16),
            Text(
              result.estimatedTime
                  ? s.estimatedChartNote
                  : result.exactTime
                  ? s.missingAngles
                  : s.dateOnlyRules,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadingSection extends StatelessWidget {
  const _ReadingSection({
    required this.section,
    required this.number,
    super.key,
  });
  final ReportSection section;
  final int number;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: goldColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$number', style: const TextStyle(color: goldColor)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                section.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (var index = 0; index < section.paragraphs.length; index++) ...[
          if (index == 0)
            Text(section.paragraphs[index])
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: goldColor.withValues(alpha: index == 1 ? .04 : .08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Builder(
                builder: (context) {
                  final paragraph = section.paragraphs[index];
                  final split = paragraph.indexOf('\n');
                  if (split <= 0 || split > 80) return Text(paragraph);
                  return ReadingParagraph(
                    paragraph.substring(0, split),
                    paragraph.substring(split + 1),
                  );
                },
              ),
            ),
          const SizedBox(height: 18),
        ],
      ],
    ),
  );
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
