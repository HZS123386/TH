import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/dependencies.dart';
import '../../core/models/calculation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../chart/chart_wheel.dart';
import 'reports_view_model.dart';

class H5ReportPage extends StatefulWidget {
  const H5ReportPage({required this.id, super.key});

  final String id;

  @override
  State<H5ReportPage> createState() => _H5ReportPageState();
}

class _H5ReportPageState extends State<H5ReportPage>
    with WidgetsBindingObserver {
  AppDependencies? _dependencies;
  String? _owner;
  Map<String, dynamic>? _report;
  Timer? _poll;
  int _requestVersion = 0;
  bool _loading = false, _failed = false, _foreground = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependencies != null) return;
    _dependencies = DependencyScope.of(context);
    _dependencies!.session.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    _sessionChanged();
  }

  void _sessionChanged() {
    final d = _dependencies!;
    final owner = d.auth.hasH5Reports ? d.session.owner : null;
    if (_owner == owner) return;
    ++_requestVersion;
    _poll?.cancel();
    setState(() {
      _owner = owner;
      _report = null;
      _failed = _loading = false;
    });
    if (owner != null && _foreground) unawaited(_load());
  }

  Future<void> _load() async {
    if (_owner == null || _loading || !_foreground) return;
    _poll?.cancel();
    final version = ++_requestVersion;
    setState(() => _loading = true);
    try {
      final report = await _dependencies!.reports.repository.readH5(widget.id);
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _report = report;
        _failed = false;
      });
      if (_foreground && _isGenerating(report)) {
        _poll = Timer(const Duration(seconds: 4), _load);
      }
    } catch (_) {
      if (mounted && version == _requestVersion) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _poll?.cancel();
    if (_foreground) unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dependencies?.session.removeListener(_sessionChanged);
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), report = _report;
    final waiting = _loading || (_dependencies?.session.loading ?? false);
    if (report == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (waiting)
                const CircularProgressIndicator()
              else ...[
                Text(s.h5ReportUnavailable, textAlign: TextAlign.center),
                if (_owner != null)
                  TextButton(onPressed: _load, child: Text(s.h5Refresh)),
              ],
            ],
          ),
        ),
      );
    }

    final input = _object(report['input']);
    final profile = _object(input['profile']);
    final preview = _object(report['preview']);
    final personal = _object(report['personal']);
    final relationship = _object(personal['relationship']);
    final full = report['access'] == 'full';
    final fullState = report['full_state'];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _text(report['title']),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: s.h5Refresh,
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Text(
          h5ReportStatusLabel(s, full, fullState),
          style: const TextStyle(color: goldColor),
        ),
        const SizedBox(height: 8),
        Text(
          [
            _text(profile['birth_date']),
            _text(profile['birth_time']),
            (_text(_object(report['location'])['name']).isNotEmpty
                ? _text(_object(report['location'])['name'])
                : _text(profile['birthplace'])),
          ].where((part) => part.isNotEmpty).join(' · '),
        ),
        if (_failed ||
            ['failed', 'unavailable'].contains(report['preview_state']) ||
            (full && ['failed', 'unavailable'].contains(fullState)))
          Text(
            s.h5ReportUnavailable,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (full && fullState == 'limited')
          Text(
            s.h5ReportLimitedHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (_isGenerating(report)) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          if (!full) ...[const SizedBox(height: 6), Text(s.reportPending)],
        ],
        if (preview.isNotEmpty || _lines(personal['free_lines']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: FateCard(
              gold: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_text(input['user_question']).isNotEmpty)
                    Text(
                      _text(input['user_question']),
                      style: const TextStyle(color: goldColor),
                    ),
                  if (preview.isNotEmpty)
                    _ReportPoint(_object(preview['summary'])),
                  if (relationship.isNotEmpty) ...[
                    _ReportPoint(relationship),
                    if (_text(relationship['action']).isNotEmpty)
                      Text(_text(relationship['action'])),
                  ],
                  for (final line in _lines(personal['free_lines']))
                    _ReportPoint({'text': line}),
                  for (final trait in _objects(personal['traits']))
                    _ReportPoint(trait),
                  if (_text(personal['opportunity_action']).isNotEmpty)
                    Text(_text(personal['opportunity_action'])),
                  if (preview['career_answer'] is Map)
                    _ReportPoint(_object(preview['career_answer'])),
                  for (final trait in _objects(preview['traits']))
                    _ReportPoint(trait),
                ],
              ),
            ),
          ),
        if (_object(report['chart']).isNotEmpty)
          _H5Chart(id: widget.id, chart: _object(report['chart'])),
        if (full) ...[
          ..._personalSections(personal, _objects(report['catalog'])),
          for (final chapter in _objects(report['chapters']))
            _ReportSection(
              key: ValueKey(chapter['key']),
              title: _text(chapter['title']),
              children: [
                _ReportPoint(_object(chapter['summary'])),
                for (final group in [
                  ('insights', s.h5Insight),
                  ('watchpoints', s.h5Watchpoint),
                  ('actions', s.myActions),
                ])
                  if (_objects(chapter[group.$1]).isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(group.$2, style: const TextStyle(color: goldColor)),
                    for (final point in _objects(chapter[group.$1]))
                      _ReportPoint(point),
                  ],
              ],
            ),
          if (report['plan'] is Map)
            _ReportSection(
              title: s.h5Plan,
              children: [
                for (final phase in _objects(
                  _object(report['plan'])['phases'],
                )) ...[
                  _ReportPoint(phase),
                  for (final action in _objects(phase['actions']))
                    _ReportPoint(action),
                ],
              ],
            ),
        ],
      ],
    );
  }
}

Iterable<String> _lines(Object? value) => value is List
    ? value.whereType<String>().where((line) => line.trim().isNotEmpty)
    : const [];

Iterable<Widget> _personalSections(
  Map<String, dynamic> personal,
  Iterable<Map<String, dynamic>> catalog,
) sync* {
  final relationship = _object(personal['relationship_sections']);
  final talent = _object(personal['talent']);
  final themes = _object(personal['themes']);
  final nodes = _objects(personal['nodes']).toList();
  for (final section in catalog) {
    final key = _text(section['key']);
    final paragraphs = _lines(relationship[key]);
    final theme = _object(themes[key]);
    final children = <Widget>[
      for (final paragraph in paragraphs) _ReportPoint({'text': paragraph}),
      if (theme.isNotEmpty) _ReportPoint(theme),
      if (talent.isNotEmpty && ['talent', 'natal'].contains(key))
        _ReportPoint(talent),
      if (key == 'career')
        for (final direction in _objects(talent['directions']))
          _ReportPoint(direction),
      for (final (index, node) in nodes.indexed)
        if (key == 'plan' || key == 'node-${index + 1}') ...[
          _ReportPoint({
            'title': node['month'],
            'text': node['theme'],
            'evidence': node['evidence'],
          }),
          for (final field in ['benefit', 'caution', 'action'])
            if (_text(node[field]).isNotEmpty)
              _ReportPoint({'text': node[field]}),
        ],
    ];
    if (children.isNotEmpty) {
      yield _ReportSection(
        key: ValueKey(key),
        title: _text(section['title']),
        children: children,
      );
    }
  }
}

bool _isGenerating(Map<String, dynamic> report) {
  const running = ['queued', 'pending', 'generating'];
  return running.contains(report['preview_state']) ||
      (report['access'] == 'full' && running.contains(report['full_state']));
}

Map<String, dynamic> _object(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

Iterable<Map<String, dynamic>> _objects(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>() : const [];

String _text(Object? value) => value is String ? value : '';

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: FateCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Text(title),
        children: children,
      ),
    ),
  );
}

class _ReportPoint extends StatelessWidget {
  const _ReportPoint(this.point);

  final Map<String, dynamic> point;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final period = _object(point['period']);
    final signals = point['signals'], steps = point['steps'];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_text(point['title']).isNotEmpty)
            Text(
              _text(point['title']),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (period['year'] is int && period['month'] is int)
            Text(
              '${period['year']}-${'${period['month']}'.padLeft(2, '0')}',
              style: const TextStyle(color: goldColor),
            ),
          if (_text(point['text']).isNotEmpty) Text(_text(point['text'])),
          if (signals is List)
            for (final signal in signals.whereType<String>()) Text('• $signal'),
          if (_text(point['response']).isNotEmpty)
            Text(_text(point['response'])),
          if (steps is List)
            for (final (index, step) in steps.whereType<String>().indexed)
              Text('${index + 1}. $step'),
          for (final (field, label) in [
            ('example', s.h5Example),
            ('pitfall', s.h5Pitfall),
            ('check', s.h5Check),
          ])
            if (_text(point[field]).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$label\n${point[field]}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          for (final fact in _objects(point['evidence']))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                [
                  _text(fact['title']),
                  _text(fact['detail']),
                ].where((text) => text.isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _H5Chart extends StatefulWidget {
  const _H5Chart({required this.id, required this.chart});

  final String id;
  final Map<String, dynamic> chart;

  @override
  State<_H5Chart> createState() => _H5ChartState();
}

class _H5ChartState extends State<_H5Chart> {
  String _selected = '';

  @override
  Widget build(BuildContext context) {
    final points = _objects(widget.chart['planets']);
    final exact = widget.chart['precision'] == 'exact';
    final result = CalculationSnapshot(
      id: widget.id,
      engineVersion: _text(widget.chart['engine']),
      rulesetVersion: '',
      exactTime: exact,
      planets: [
        for (final point in points)
          if (ChartPlanet.keys.contains(point['id']) &&
              point['longitude'] is num)
            ChartPlanet(
              point['id'] as String,
              (point['longitude'] as num).toDouble(),
            ),
      ],
      ascendant: exact
          ? points
                .where((point) => point['id'] == 'ascendant')
                .map((point) => (point['longitude'] as num?)?.toDouble())
                .firstOrNull
          : null,
      houses: {
        for (final house in _objects(widget.chart['houses']))
          if (house['number'] is int && house['longitude'] is num)
            house['number'] as int: (house['longitude'] as num).toDouble(),
      },
    );
    if (points.isEmpty) return const SizedBox.shrink();
    return _ReportSection(
      title: AppLocalizations.of(context).chart,
      children: [
        if (result.planets.isNotEmpty)
          ChartWheel(
            result: result,
            selected: _selected,
            onSelected: (key) => setState(() => _selected = key),
          ),
        for (final point in points)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              '${_text(point['label'])} · ${_text(point['sign_name'])} ${point['degree'] is num ? '${(point['degree'] as num).toStringAsFixed(1)}°' : ''}',
              style: TextStyle(
                color: point['id'] == _selected ? goldColor : null,
              ),
            ),
          ),
      ],
    );
  }
}
