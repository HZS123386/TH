import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../core/models/birth_profile.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

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
            PageHeading(
              s.thaiGuide,
              s.thaiChartIntro,
              icon: Icons.explore_outlined,
            ),
            if (birth == null)
              FilledButton(
                onPressed: () => context.push('/birth'),
                child: Text(s.startThaiGuide),
              )
            else
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
  late var _request = _calculate();

  Future<Map<String, dynamic>> _calculate() {
    final birth = widget.birth, d = widget.dependencies;
    if (!birth.exactTime) return Future.value({'status': 'time-unknown'});
    return d.api.request(
      'POST',
      '/api/thai-chart/preview',
      authenticated: false,
      body: {
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
        'language': d.session.locale.languageCode,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return FutureBuilder(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final result = snapshot.data;
        final chart = result?['chart'] as Map?;
        final points = chart?['points'] as Map?;
        final labels = {'ascendant': s.ascendant, 'sun': s.sun, 'moon': s.moon};
        return FateCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.birth.date} · ${widget.birth.place}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              if (snapshot.hasError || result == null) ...[
                Text(s.error),
                TextButton(
                  onPressed: () => setState(() => _request = _calculate()),
                  child: Text(s.retry),
                ),
              ] else if (result['status'] == 'time-unknown')
                Text(s.unknownTime)
              else if (result['status'] == 'location-required')
                Text(s.selectBirthCity)
              else if (points != null) ...[
                for (final entry in points.entries)
                  if (entry.value is Map)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        labels[entry.key] ??
                            entry.value['nameThai']?.toString() ??
                            entry.key.toString(),
                      ),
                      trailing: Text(
                        '${entry.value['signName'] ?? ''}  ${entry.value['degrees'] ?? '–'}°',
                        style: const TextStyle(color: goldColor),
                      ),
                    ),
              ] else
                Text(s.error),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/birth'),
                child: Text(s.editBirth),
              ),
            ],
          ),
        );
      },
    );
  }
}
