import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../core/models/birth_profile.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import 'thai_rasi_wheel.dart';
import 'thai_reading_section.dart';

void _openBirthDetails(BuildContext context) {
  if (DependencyScope.of(context).session.thaiAstrologyOnly) {
    context.go('/home');
  } else {
    context.push('/birth');
  }
}

class ThaiChartPage extends StatelessWidget {
  const ThaiChartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: d.session,
      builder: (context, _) {
        final birth = d.session.profile;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (birth == null) ...[
              PageHeading(
                s.thaiGuide,
                s.thaiChartIntro,
                icon: Icons.explore_outlined,
              ),
              FilledButton(
                onPressed: () => _openBirthDetails(context),
                child: Text(s.startThaiGuide),
              ),
            ] else
              _ThaiChartResult(
                key: ValueKey(d.session.scope),
                birth: birth,
                dependencies: d,
              ),
          ],
        );
      },
    );
  }
}

class _ThaiChartResult extends StatefulWidget {
  const _ThaiChartResult({
    required this.birth,
    required this.dependencies,
    super.key,
  });
  final BirthProfile birth;
  final AppDependencies dependencies;

  @override
  State<_ThaiChartResult> createState() => _ThaiChartResultState();
}

class _ThaiChartResultState extends State<_ThaiChartResult> {
  late Future<Map<String, dynamic>> _request;
  late final Future<String?> _cityName;

  @override
  void initState() {
    super.initState();
    _request = _calculate();
    _cityName = _lookupCityName();
  }

  Future<String?> _lookupCityName() async {
    final birth = widget.birth;
    final session = widget.dependencies.session;
    final placeId = birth.placeId;
    final language = session.locale.languageCode;
    if (placeId == null ||
        !placeId.startsWith('geonames:') ||
        language == 'en') {
      return null;
    }
    try {
      final places = await session.profiles.locations(
        placeId,
        language,
        country: birth.countryCode ?? '',
        level: 'detail',
      );
      final name = places.items.firstOrNull?['label'];
      return name is String && name.trim().isNotEmpty ? name : null;
    } catch (_) {
      // Chart results can still use the saved place while the directory is unavailable.
      return null;
    }
  }

  Map<String, dynamic> get _profile {
    final birth = widget.birth;
    return {
      'birth_date': birth.date,
      'birth_time': birth.time,
      'timezone': birth.timezone,
      'birthplace': birth.place,
      'country_code': birth.countryCode,
      'location_id': birth.placeId?.startsWith('geonames:') == true
          ? birth.placeId
          : null,
      'latitude': birth.latitude,
      'longitude': birth.longitude,
      'language': widget.dependencies.session.locale.languageCode,
    };
  }

  Future<Map<String, dynamic>> _calculate() => widget.dependencies.api.request(
    'POST',
    '/api/thai-chart/preview',
    authenticated: false,
    body: {
      ..._profile,
      // The saved profile keeps the time unknown when noon is used to calculate.
      'birth_time': widget.birth.time ?? '12:00',
    },
  );

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final result = snapshot.data;
        final status = result?['status'];
        final chart = result?['chart'];
        final points = chart is Map && chart['points'] is Map
            ? chart['points'] as Map
            : null;
        final ready = status == 'ready' && points?['ascendant'] is Map;
        final rasi = ready ? ThaiRasiData.fromChart(chart) : null;
        final zodiacNames = s.zodiacNames;
        final chartCard = FateCard(
          gold: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.myChart, style: textTheme.titleLarge),
              const SizedBox(height: 8),
              FutureBuilder<String?>(
                future: _cityName,
                builder: (context, city) {
                  final name = city.data;
                  final country = s.birthCountries[widget.birth.countryCode];
                  final place = name == null
                      ? widget.birth.place
                      : [name, ?country].join(', ');
                  return Text(
                    '${widget.birth.date} · $place',
                    style: textTheme.bodySmall,
                  );
                },
              ),
              const SizedBox(height: 10),
              if (status == 'location-required')
                Text(s.selectBirthCity)
              else if (rasi != null) ...[
                if (!widget.birth.exactTime) ...[
                  Text(s.estimatedChart, style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                ],
                ThaiRasiWheel(data: rasi, label: s.myChart),
                if (!widget.birth.exactTime) ...[
                  const SizedBox(height: 10),
                  Text(s.thaiEstimatedChartNote, style: textTheme.bodySmall),
                ],
              ] else ...[
                Text(s.error),
                TextButton(
                  onPressed: () {
                    final request = _calculate();
                    setState(() {
                      _request = request;
                    });
                  },
                  child: Text(s.retry),
                ),
              ],
              if (!ready) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _openBirthDetails(context),
                  child: Text(s.editBirth),
                ),
              ],
            ],
          ),
        );
        if (!ready) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: chartCard,
            ),
          );
        }
        final positions = FateCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.thaiChartPositions, style: textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final entry in points!.entries)
                if (entry.value case final Map point)
                  _pointRow(s, zodiacNames, entry.key.toString(), point),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _openBirthDetails(context),
                child: Text(s.editBirth),
              ),
            ],
          ),
        );
        return Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 680) {
                  return Column(spacing: 16, children: [chartCard, positions]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 24,
                  children: [
                    Expanded(child: chartCard),
                    Expanded(child: positions),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ThaiReadingSection(profile: _profile),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pointRow(
    AppLocalizations s,
    List<String> zodiacNames,
    String key,
    Map point,
  ) {
    final sign = point['sign'];
    final signName = sign is int && sign >= 0 && sign < zodiacNames.length
        ? zodiacNames[sign]
        : point['signName'] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: OverflowBar(
        alignment: MainAxisAlignment.spaceBetween,
        spacing: 12,
        overflowSpacing: 4,
        overflowAlignment: OverflowBarAlignment.start,
        children: [
          Text(s.thaiPointName(key, point['nameThai']?.toString())),
          Text(
            '$signName  ${point['degrees'] ?? '–'}°',
            style: const TextStyle(color: goldColor),
          ),
        ],
      ),
    );
  }
}
