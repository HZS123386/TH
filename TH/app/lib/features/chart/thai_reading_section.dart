import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/dependencies.dart';
import '../../core/network/api_client.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

enum _ThaiReadingTopic {
  overview,
  work,
  money,
  love,
  family,
  annual;

  String label(AppLocalizations s) => switch (this) {
    overview => s.thaiReadingOverview,
    work => s.thaiReadingWork,
    money => s.thaiReadingMoney,
    love => s.thaiReadingLove,
    family => s.thaiReadingFamily,
    annual => s.thaiReadingAnnual,
  };
}

class ThaiReadingSection extends StatefulWidget {
  const ThaiReadingSection({required this.profile, super.key});

  final Map<String, dynamic> profile;

  @override
  State<ThaiReadingSection> createState() => _ThaiReadingSectionState();
}

class _ThaiReadingSectionState extends State<ThaiReadingSection> {
  final _reports = <(_ThaiReadingTopic, int?), Map<String, dynamic>>{};
  var _topic = _ThaiReadingTopic.overview;
  var _yearText =
      '${DateTime.now().toUtc().add(const Duration(hours: 7)).year}';
  var _loading = false;
  String? _status;

  int? get _year {
    final value = int.tryParse(_yearText);
    return value != null && value >= 1901 && value <= 2100 ? value : null;
  }

  bool get _exactTime => widget.profile['birth_time'] != null;

  Future<void> _generate() async {
    final year = _topic == _ThaiReadingTopic.annual ? _year : null;
    final key = (_topic, year);
    if (_loading ||
        !_exactTime ||
        _reports.containsKey(key) ||
        (_topic == _ThaiReadingTopic.annual && year == null)) {
      return;
    }
    final api = DependencyScope.of(context).api;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      final response = await api.request(
        'POST',
        '/api/thai-reading',
        authenticated: false,
        timeout: const Duration(seconds: 150),
        body: {
          'profile': widget.profile,
          'reading': key.$1.name,
          'year': ?year,
        },
      );
      if (!mounted) return;
      final input = response['input'];
      final report = response['report'];
      if (input is! Map ||
          input['reading'] != key.$1.name ||
          (year != null && input['year'] != year) ||
          report is! Map<String, dynamic> ||
          report['language'] != widget.profile['language']) {
        throw const ApiFailure('invalid_response');
      }
      final generation = report['generation'];
      if (generation is! Map) throw const ApiFailure('invalid_response');
      final state = generation['state'];
      if (state == 'ready') {
        if (!_hasCompleteReport(report)) {
          throw const ApiFailure('invalid_response');
        }
        _reports[key] = report;
      } else {
        _status = switch ((state, generation['failure_code'])) {
          ('pending', _) => 'pending',
          ('limited' || 'unconfigured', _) => 'limited',
          ('unavailable', 'model_timeout') => 'timeout',
          (
            'unavailable',
            'model_rate_limit' || 'model_overloaded' || 'model_quota_exhausted',
          ) =>
            'limited',
          _ => 'unavailable',
        };
      }
    } on ApiFailure catch (error) {
      _status = error.code == 'timeout'
          ? 'timeout'
          : error.status == 429
          ? 'limited'
          : 'unavailable';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _hasCompleteReport(Map<String, dynamic> report) {
    final sections = report['sections'];
    if (!_hasText(report['summary']) || sections is! List) return false;
    return const ['interpretation', 'opportunities', 'advice'].every(
      (id) => sections.whereType<Map>().any((section) {
        final items = section['items'];
        return section['id'] == id &&
            _hasText(section['title']) &&
            items is List &&
            items.isNotEmpty &&
            items.every(
              (item) =>
                  item is Map &&
                  _hasText(item['title']) &&
                  _hasText(item['text']),
            );
      }),
    );
  }

  bool _hasText(Object? value) => value is String && value.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final theme = Theme.of(context).textTheme;
    final annual = _topic == _ThaiReadingTopic.annual;
    final report = _reports[(_topic, annual ? _year : null)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FateCard(
          gold: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.thaiReadingTitle, style: theme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final topic in _ThaiReadingTopic.values)
                    if (_exactTime)
                      ChoiceChip(
                        label: Text(topic.label(s)),
                        selected: _topic == topic,
                        onSelected: _loading
                            ? null
                            : (selected) {
                                if (selected) {
                                  setState(() {
                                    _topic = topic;
                                    _status = null;
                                  });
                                }
                              },
                      )
                    else
                      Chip(label: Text(topic.label(s))),
                ],
              ),
              const SizedBox(height: 12),
              if (!_exactTime)
                Text(s.thaiReadingNeedsTime, style: theme.bodySmall)
              else ...[
                if (annual) ...[
                  TextFormField(
                    initialValue: _yearText,
                    enabled: !_loading,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: s.thaiReadingYear,
                      errorText: _year == null ? s.thaiReadingYearRange : null,
                    ),
                    onChanged: (value) => setState(() {
                      _yearText = value;
                      _status = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_loading)
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(s.thaiReadingLoading)),
                      ],
                    ),
                  )
                else if (report == null) ...[
                  if (_status != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(switch (_status) {
                        'pending' => s.thaiReadingPending,
                        'timeout' => s.reportServiceTimeout,
                        'limited' || 'unconfigured' => s.reportServiceBusy,
                        _ => s.reportFailedText,
                      }),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(s.thaiReadingPermission, style: theme.bodySmall),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: annual && _year == null ? null : _generate,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(s.consentGenerate),
                  ),
                ],
              ],
            ],
          ),
        ),
        if (report != null) ...[
          const SizedBox(height: 12),
          FateCard(
            child: ReadingParagraph(s.summary, report['summary'] as String),
          ),
          for (final section
              in (report['sections'] as List).whereType<Map>()) ...[
            const SizedBox(height: 12),
            _ReportSection(section: section),
          ],
        ],
      ],
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.section});

  final Map section;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final theme = Theme.of(context).textTheme;
    final items = section['items'];
    return FateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(section['title']?.toString() ?? '', style: theme.titleMedium),
          if (items is List)
            for (final item in items.whereType<Map>())
              if (item['title'] is String && item['text'] is String)
                _ReportPoint(
                  item: item,
                  showDetails: section['id'] != 'interpretation',
                  s: s,
                ),
        ],
      ),
    );
  }
}

class _ReportPoint extends StatelessWidget {
  const _ReportPoint({
    required this.item,
    required this.showDetails,
    required this.s,
  });

  final Map item;
  final bool showDetails;
  final AppLocalizations s;

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String;
    final text = item['text'] as String;
    final period = item['period'];
    final month = period is Map ? period['month'] : null;
    final year = period is Map ? period['year'] : null;
    final date = month is int && month >= 1 && month <= 12 && year is int
        ? DateFormat.yMMMM(s.localeName).format(DateTime.utc(year, month))
        : null;
    final heading = date == null ? title : '$date · $title';
    if (!showDetails) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: ReadingParagraph(heading, text),
      );
    }
    final signals = item['signals'];
    final steps = item['steps'];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(heading),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: [
        Text(text),
        if (signals is List && signals.isNotEmpty)
          _detail(
            s.thaiReadingSignals,
            signals.whereType<String>().map((v) => '• $v').join('\n'),
          ),
        if (item['response'] case final String value)
          _detail(s.thaiReadingResponse, value),
        if (steps is List && steps.isNotEmpty)
          _detail(
            s.thaiReadingSteps,
            steps
                .whereType<String>()
                .indexed
                .map((entry) => '${entry.$1 + 1}. ${entry.$2}')
                .join('\n'),
          ),
        if (item['example'] case final String value)
          _detail(s.thaiReadingExample, value),
        if (item['pitfall'] case final String value)
          _detail(s.thaiReadingPitfall, value),
        if (item['check'] case final String value)
          _detail(s.thaiReadingCheck, value),
      ],
    );
  }

  Widget _detail(String title, String text) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: ReadingParagraph(title, text),
  );
}
