import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../core/models/calculation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import 'chart_wheel.dart';
import '../account/birth_page.dart';

class ChartPage extends StatefulWidget {
  const ChartPage({this.example = false, super.key});
  final bool example;
  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  String selected = 'sun';
  String? requestedScope;
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([d.chart, d.session]),
      builder: (context, _) {
        if (!widget.example && d.session.profile?.isServerRevision != true) {
          return const BirthPage();
        }
        final result = widget.example ? teachingChart : d.chart.result;
        if (!widget.example &&
            result == null &&
            !d.chart.loading &&
            d.session.capabilities.western &&
            d.session.profile?.isServerRevision == true &&
            requestedScope != d.session.scope) {
          requestedScope = d.session.scope;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) d.chart.calculate();
          });
        }
        final chosen = result?.planets.where((p) => p.key == selected);
        final planet = chosen != null && chosen.isNotEmpty
            ? chosen.first
            : null;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.system,
                style: const TextStyle(color: goldColor, fontSize: 11),
              ),
              const SizedBox(height: 8),
              PageHeading(s.myChart, s.myChartText),
              if (widget.example)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: FateCard(
                    child: Text(
                      '${s.exampleBadge}\n${s.exampleNote}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              if (result == null)
                FateCard(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Icon(
                          Icons.explore_outlined,
                          size: 110,
                          color: goldColor,
                        ),
                      ),
                      Text(
                        d.chart.loading ? s.waiting : s.calculateChart,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        d.chart.error != null
                            ? s.chartError(d.chart.error)
                            : s.myChartText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: d.chart.loading ? null : d.chart.calculate,
                        child: Text(
                          d.chart.loading ? s.waiting : s.calculateChart,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/chart?example=1'),
                        child: Text(s.example),
                      ),
                    ],
                  ),
                )
              else ...[
                if (!widget.example) ...[
                  Text(
                    s.chartSource,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.chartRules,
                    style: const TextStyle(color: goldColor, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                ],
                FateCard(
                  gold: true,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ChartWheel(
                        result: result,
                        selected: selected,
                        onSelected: (key) => setState(() => selected = key),
                      ),
                      Row(
                        children: [
                          for (final entry in [
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
                                padding: const EdgeInsets.all(5),
                                child: Column(
                                  children: [
                                    Text(
                                      entry.$1,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      entry.$2 == null
                                          ? s.emptyValue
                                          : s.zodiacNames[(entry.$2! / 30)
                                                .floor()],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: goldColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  s.planetHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (planet != null)
                  FateCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${planet.symbol}  ${s.planetName(planet.key)}',
                          style: const TextStyle(
                            fontSize: 19,
                            color: goldColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(s.position(planet.longitude)),
                        const SizedBox(height: 10),
                        Text(
                          s.planetMeaning(planet.key),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (!result.exactTime ||
                    result.ascendant == null ||
                    result.houses.isEmpty)
                  Text(
                    result.exactTime ? s.missingAngles : s.dateOnlyRules,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 18),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 0,
                      label: Text(
                        s.planets,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text(
                        s.houses,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text(
                        s.aspects,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                  selected: {tab},
                  onSelectionChanged: (value) =>
                      setState(() => tab = value.first),
                ),
                const SizedBox(height: 15),
                FateCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Column(
                    children: [
                      if (tab == 0)
                        for (final p in result.planets)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Text(
                              p.symbol,
                              style: const TextStyle(
                                fontSize: 22,
                                color: goldColor,
                              ),
                            ),
                            title: Text(
                              '${s.planetName(p.key)}${p.retrograde ? ' · ${s.retrograde}' : ''}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: Text(
                              '${s.position(p.longitude)}${p.house == null ? '' : '\n${s.house} ${p.house}'}',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 11,
                                color: mutedColor,
                              ),
                            ),
                            onTap: () => setState(() => selected = p.key),
                          ),
                      if (tab == 1)
                        if (result.houses.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(15),
                            child: Text(s.emptyValue),
                          )
                        else
                          for (final h in result.houses.entries)
                            ListTile(
                              title: Text('${s.house} ${h.key}'),
                              trailing: Text(s.position(h.value)),
                            ),
                      if (tab == 2)
                        if (result.aspects.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(15),
                            child: Text(s.emptyValue),
                          )
                        else
                          for (final a in result.aspects)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${s.planetName(a.from)} · ${s.planetName(a.to)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                '${s.aspectName(a.angle)}\n${a.orb == null ? '${a.angle.toInt()}°' : '${s.orb} ${a.orb!.toStringAsFixed(2)}°'}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  color: goldColor,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go(
                    widget.example ? '/reports/reading?example=1' : '/reports',
                  ),
                  child: Text(s.chartRead),
                ),
              ],
              if (d.session.profile != null && !widget.example)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: OutlinedButton(
                    onPressed: () => context.go('/birth'),
                    child: Text(s.editBirth),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
