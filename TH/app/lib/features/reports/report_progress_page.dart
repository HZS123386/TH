import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../core/models/report.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import 'reports_view_model.dart';

class ReportProgressPage extends StatefulWidget {
  const ReportProgressPage({
    required this.destination,
    required this.backLocation,
    this.reportId,
    super.key,
  });
  final String destination, backLocation;
  final String? reportId;
  @override
  State<ReportProgressPage> createState() => _ReportProgressPageState();
}

class _ReportProgressPageState extends State<ReportProgressPage> {
  ReportsViewModel? model;
  String? requestedScope;
  bool redirecting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    model ??= DependencyScope.of(context).reports;
  }

  @override
  void dispose() {
    model?.setActive(false, view: this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([d.reports, d.session]),
      builder: (context, _) {
        if (!d.session.loading && requestedScope != d.session.scope) {
          requestedScope = d.session.scope;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            if (d.reports.reference == null ||
                (widget.reportId != null &&
                    d.reports.reference?.id != widget.reportId)) {
              final saved = d.reports.repository.active(d.session.owner);
              if (saved != null &&
                  (widget.reportId == null || saved.id == widget.reportId)) {
                await d.reports.resume(saved);
              }
            }
            if (mounted) d.reports.setActive(true, view: this);
          });
        }
        final current = d.reports.report;
        final report = widget.reportId == null || current?.id == widget.reportId
            ? current
            : null;
        final progress = report?.progress ?? const ReportGenerationProgress();
        if (report?.previewState == 'ready' &&
            !report!.generating &&
            !report.failed &&
            !redirecting) {
          redirecting = true;
          final completedScope = d.session.scope, completedId = report.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                d.session.scope == completedScope &&
                d.reports.report?.id == completedId &&
                d.reports.report?.previewState == 'ready' &&
                ModalRoute.of(context)?.isCurrent == true) {
              context.go(widget.destination);
            }
          });
        }
        final failed = report?.failed == true;
        final title = failed
            ? s.progressFailed
            : switch (progress.stage) {
                'writing' => s.progressWriting,
                'reviewing' => s.progressChecking,
                'refining' => s.progressRefining,
                'complete' => s.progressComplete,
                _ => s.progressPreparing,
              };
        final topicTitles = [
          s.progressPersonality,
          s.progressCareer,
          s.progressMoney,
          s.progressRelationships,
          s.progressWatch,
          s.progressActions,
        ];
        final failure = switch (report?.failureReason) {
          'service_busy' => s.reportServiceBusy,
          'service_timeout' => s.reportServiceTimeout,
          _ => s.reportFailedText,
        };
        return SingleChildScrollView(
          key: const ValueKey('reading-progress'),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.progressTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.progressIntro,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FateCard(
                gold: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      color: goldColor,
                      size: 32,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${progress.percent}%',
                      key: const ValueKey('reading-progress-percent'),
                      style: const TextStyle(
                        fontSize: 38,
                        color: goldColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      key: const ValueKey('reading-progress-bar'),
                      value: progress.percent / 100,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      semanticsLabel: title,
                      semanticsValue: '${progress.percent}%',
                    ),
                    const SizedBox(height: 18),
                    Text(
                      s.progressTopics(
                        progress.completedTopics.length,
                        ReportGenerationProgress.topics.length,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < topicTitles.length; index++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Icon(
                              progress.completedTopics.contains(
                                    ReportGenerationProgress.topics[index],
                                  )
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 18,
                              color:
                                  progress.completedTopics.contains(
                                    ReportGenerationProgress.topics[index],
                                  )
                                  ? goldColor
                                  : mutedColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(topicTitles[index])),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (failed) ...[
                Text(failure),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(widget.destination),
                  child: Text(s.progressReturn),
                ),
              ] else if (d.reports.error != null) ...[
                Text(s.progressDisconnected),
                TextButton(
                  onPressed: d.reports.loading ? null : d.reports.refresh,
                  child: Text(s.progressReconnect),
                ),
              ],
              TextButton(
                onPressed: () => context.go(widget.backLocation),
                child: Text(s.progressLater),
              ),
            ],
          ),
        );
      },
    );
  }
}
