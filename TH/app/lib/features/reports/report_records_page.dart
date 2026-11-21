import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../core/network/api_client.dart';
import '../../data/reports_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

enum ReportRecordsOrigin { chart, profile, reports }

class ReportRecordsPage extends StatefulWidget {
  const ReportRecordsPage({this.origin = ReportRecordsOrigin.chart, super.key});
  final ReportRecordsOrigin origin;

  @override
  State<ReportRecordsPage> createState() => _ReportRecordsPageState();
}

class _ReportRecordsPageState extends State<ReportRecordsPage> {
  final search = TextEditingController();
  Timer? debounce;
  String? loadedScope;
  bool searchPending = false;

  Map<String, String> get readingParameters => {
    'from': 'history',
    if (widget.origin != ReportRecordsOrigin.chart)
      'origin': widget.origin.name,
  };

  void load() {
    if (!mounted) return;
    setState(() => searchPending = false);
    DependencyScope.of(context).reports.loadHistory(query: search.text.trim());
  }

  void searchChanged(String value) {
    debounce?.cancel();
    setState(() => searchPending = true);
    debounce = Timer(const Duration(milliseconds: 300), load);
  }

  void openRecord(ReportReference reference) {
    DependencyScope.of(context).reports.resume(reference);
    context.go(
      Uri(
        path: '/chart/reading',
        queryParameters: readingParameters,
      ).toString(),
    );
  }

  Future<void> deleteRecord(ReportReference reference) async {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    final scope = d.session.scope;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteReport),
        content: Text('${s.deleteReportConfirm}\n\n${reference.number ?? ''}'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-report'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.deleteReport),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || scope != d.session.scope) return;
    String message;
    try {
      final deleted = await d.reports.deleteRecord(reference);
      if (!deleted) return;
      message = s.reportDeleted;
    } on ApiFailure catch (failure) {
      message = failure.status == 409
          ? s.reportDeleteBusy
          : s.deleteReportFailed;
    } catch (_) {
      message = s.deleteReportFailed;
    }
    if (mounted && scope == d.session.scope) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([d.reports, d.session]),
      builder: (context, _) {
        if (!d.session.loading && loadedScope != d.session.scope) {
          loadedScope = d.session.scope;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) load();
          });
        }
        final busy = searchPending || d.reports.historyLoading;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeading(s.reportRecords, s.reportRecordsIntro),
                  TextField(
                    key: const ValueKey('report-number-search'),
                    controller: search,
                    maxLength: 64,
                    autocorrect: false,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: s.searchReportNumber,
                      counterText: '',
                      prefixIcon: const Icon(Icons.search, color: goldColor),
                      suffixIcon: search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: s.clearSearch,
                              onPressed: () {
                                search.clear();
                                debounce?.cancel();
                                load();
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: searchChanged,
                    onSubmitted: (_) {
                      debounce?.cancel();
                      load();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: busy
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      children: [
                        if (d.reports.historyError != null)
                          FateCard(
                            child: Column(
                              children: [
                                Text(s.loadReportsFailed),
                                const SizedBox(height: 14),
                                OutlinedButton(
                                  onPressed: load,
                                  child: Text(s.refreshRecords),
                                ),
                              ],
                            ),
                          )
                        else if (d.reports.history.isEmpty)
                          FateCard(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.menu_book_outlined,
                                  color: goldColor,
                                  size: 40,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  search.text.trim().isEmpty
                                      ? s.noSavedReports
                                      : s.noMatchingReports,
                                  textAlign: TextAlign.center,
                                ),
                                if (search.text.trim().isEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    s.reportEmptyText,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 18),
                                  OutlinedButton(
                                    onPressed: () => context.go('/chart'),
                                    child: Text(s.continueChart),
                                  ),
                                ],
                              ],
                            ),
                          )
                        else
                          for (final reference in d.reports.history)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: FateCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: ListTile(
                                  key: ValueKey(
                                    'report-record-${reference.id}',
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    s.reportTitle,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.reportNumberLabel,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        SelectableText(
                                          reference.number ?? '—',
                                          style: const TextStyle(
                                            color: goldColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (reference.createdAt != null)
                                          Text(
                                            '${s.generatedAt} · ${MaterialLocalizations.of(context).formatMediumDate(reference.createdAt!.toLocal())} '
                                            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(reference.createdAt!.toLocal()))}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        Text(
                                          reference.state == 'running'
                                              ? s.reportRunning
                                              : reference.state == 'failed'
                                              ? s.reportFailedShort
                                              : s.reportReady,
                                          style: const TextStyle(
                                            color: goldColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton.icon(
                                          key: ValueKey(
                                            'open-report-${reference.id}',
                                          ),
                                          onPressed:
                                              d.reports.deleting.contains(
                                                reference.id,
                                              )
                                              ? null
                                              : () => openRecord(reference),
                                          icon: const Icon(
                                            Icons.menu_book_outlined,
                                            size: 17,
                                          ),
                                          label: Text(s.openReport),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing:
                                      d.reports.deleting.contains(reference.id)
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : IconButton(
                                          key: ValueKey(
                                            'delete-report-${reference.id}',
                                          ),
                                          tooltip: s.deleteReport,
                                          onPressed:
                                              reference.state == 'running'
                                              ? null
                                              : () => deleteRecord(reference),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: mutedColor,
                                          ),
                                        ),
                                  onTap:
                                      d.reports.deleting.contains(reference.id)
                                      ? null
                                      : () {
                                          openRecord(reference);
                                        },
                                ),
                              ),
                            ),
                        if (search.text.isEmpty && d.reports.exampleSaved) ...[
                          const SizedBox(height: 20),
                          FateCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.savedReports),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(s.exampleBadge),
                                  trailing: IconButton(
                                    tooltip: s.remove,
                                    onPressed: d.reports.removeExample,
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                  onTap: () => context.go(
                                    Uri(
                                      path: '/chart/reading',
                                      queryParameters: {
                                        ...readingParameters,
                                        'example': '1',
                                      },
                                    ).toString(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }
}
