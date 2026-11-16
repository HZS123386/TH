import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../core/models/calculation.dart';
import '../../core/models/report.dart';
import '../../data/reports_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../chart/chart_wheel.dart';
import '../purchases/purchase_sheet.dart';
import 'reports_view_model.dart';

class ReportsTabPage extends StatelessWidget {
  const ReportsTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(s.reports, s.chartReportsLocation),
          FateCard(
            child: Column(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  size: 40,
                  color: goldColor,
                ),
                const SizedBox(height: 18),
                Text(s.noSavedReports, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => context.go('/chart'),
                  child: Text(s.continueChart),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({this.example = false, this.fromChart = false, super.key});
  final bool example, fromChart;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  ReportsViewModel? model;
  bool exampleExpanded = false;
  bool opening = false;
  bool movingToProgress = false;
  String? openedScope;
  final sectionKeys = <String, GlobalKey>{};
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (model != null) return;
    model = DependencyScope.of(context).reports;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      model!.setActive(!widget.example, view: this);
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
    final scope = d.session.scope;
    bool current() => mounted && scope == d.session.scope;
    if (d.session.profile?.isServerRevision != true) {
      context.go('/birth');
      return;
    }
    if (d.chart.result == null) {
      await d.chart.calculate();
      if (!current() || d.chart.result == null) return;
    }
    if (!mounted || !current()) return;
    final calculation = d.chart.result!;
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
    if (consent != true || !mounted || !current()) return;
    try {
      await d.session.configuration.consent(noticeVersion);
      if (!current()) return;
      await d.reports.generate(calculation);
    } catch (_) {
      if (mounted && current()) {
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
        if (!widget.example &&
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
        final full = widget.example ? exampleExpanded : report?.full == true;
        if (report?.generating != true) movingToProgress = false;
        if (!widget.example &&
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
        final result = widget.example
            ? teachingChart
            : report?.calculation ??
                  (d.chart.result?.id ==
                          (widget.fromChart
                              ? d.chart.result?.id
                              : d.reports.reference?.resultId)
                      ? d.chart.result
                      : null);
        final ready =
            widget.example ||
            (report != null && !report.generating && !report.failed);
        final busy =
            opening ||
            d.chart.loading ||
            d.reports.loading ||
            report?.generating == true;
        final sections = [...?report?.preview, if (full) ...?report?.sections];
        GlobalKey sectionKey(String key) =>
            sectionKeys.putIfAbsent(key, () => GlobalKey());
        return Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                key: const ValueKey('reading-scroll'),
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  ready && !full ? 100 : 28,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PageHeading(s.chartRead, s.reportIntro),
                    ),
                    if (!widget.example && report?.number != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SelectableText(
                            '${s.reportNumberLabel} · ${report!.number}',
                            style: const TextStyle(
                              color: goldColor,
                              fontSize: 13,
                            ),
                          ),
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
                    if (result != null) ...[
                      _ReadingChart(result: result),
                      const SizedBox(height: 20),
                    ],
                    if (!ready)
                      FateCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (busy) ...[
                              const Center(child: CircularProgressIndicator()),
                              const SizedBox(height: 24),
                            ],
                            Text(
                              busy
                                  ? s.reportPending
                                  : report?.failed == true
                                  ? failureText
                                  : d.reports.error != null
                                  ? s.error
                                  : s.reportEmptyText,
                            ),
                            const SizedBox(height: 16),
                            if (busy)
                              Text(
                                s.reportGeneratingText,
                                style: Theme.of(context).textTheme.bodySmall,
                              )
                            else ...[
                              FilledButton(
                                onPressed: () {
                                  if (report?.failed != true &&
                                      d.reports.reference != null &&
                                      (!widget.fromChart ||
                                          d.reports.reference?.resultId ==
                                              d.chart.result?.id) &&
                                      report == null) {
                                    d.reports.refresh();
                                  } else {
                                    generate();
                                  }
                                },
                                child: Text(
                                  d.reports.error != null
                                      ? s.resumeReport
                                      : s.generate,
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    context.go('/chart/reading?example=1'),
                                child: Text(s.exampleReport),
                              ),
                            ],
                          ],
                        ),
                      )
                    else ...[
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
                            const Divider(),
                            if (widget.example)
                              Text(
                                s.traits,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (widget.example) const SizedBox(height: 24),
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
                            if (widget.example || !full) const Divider(),
                            if (widget.example || !full)
                              Text(
                                widget.example ? s.watch : s.fullReading,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (widget.example || !full)
                              const SizedBox(height: 24),
                            if (full)
                              if (widget.example)
                                _ExampleReading(s: s)
                              else ...[
                                if (report!.generating) Text(s.reportPending),
                                for (final section in report.sections)
                                  _ReadingSection(
                                    key: sectionKey(section.key),
                                    section: section,
                                    number: sections.indexOf(section) + 1,
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
                            if (d.reports.error != null)
                              Text(
                                s.error,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (ready && !full)
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
