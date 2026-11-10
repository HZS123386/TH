import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../core/models/birth_profile.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

class BirthPage extends StatefulWidget {
  const BirthPage({super.key});
  @override
  State<BirthPage> createState() => _BirthPageState();
}

class _BirthPageState extends State<BirthPage> {
  final formKey = GlobalKey<FormState>(),
      name = TextEditingController(),
      place = TextEditingController();
  BirthProfile? original;
  String? date, time, placeId;
  String timezone = 'Asia/Bangkok';
  bool unknown = false, pending = false, initialized = false;
  String _formOwner = '';
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final session = DependencyScope.of(context).session;
    _formOwner = session.owner;
    original = session.profile;
    if (original case final p?) {
      name.text = p.name;
      place.text = p.place;
      date = p.date;
      time = p.time;
      unknown = p.time == null;
      timezone = p.timezone;
      placeId = p.placeId;
    }
  }

  Future<void> save() async {
    final s = AppLocalizations.of(context),
        session = DependencyScope.of(context).session;
    if (_formOwner != session.owner) {
      setState(() => error = s.error);
      return;
    }
    if (pending || !formKey.currentState!.validate()) return;
    if (date == null) {
      setState(() => error = s.chooseBirthDate);
      return;
    }
    if (!unknown && time == null) {
      setState(() => error = s.chooseBirthTime);
      return;
    }
    setState(() {
      pending = true;
      error = null;
    });
    try {
      await session.saveProfile(
        BirthProfile(
          date: date!,
          time: unknown ? null : time,
          timezone: timezone,
          place: place.text.trim(),
          name: name.text.trim(),
          placeId: placeId,
          id: original?.id,
          revision: original?.revision,
        ),
      );
      if (mounted) context.go('/chart');
    } catch (_) {
      if (mounted) setState(() => error = s.error);
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  Future<void> chooseCity() async {
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 430),
      backgroundColor: panelColor,
      builder: (_) => _CitySheet(
        search: (q, country) => d.session.profiles.locations(
          q,
          d.session.locale.languageCode,
          country: country,
        ),
        title: s.findCity,
        hint: s.searchBirthCity,
        errorText: s.error,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      place.text =
          (selected['display_name'] ??
                  selected['name'] ??
                  selected['label'] ??
                  '')
              .toString();
      placeId = (selected['id'] ?? selected['location_id']) as String?;
      timezone = (selected['tzid'] ?? selected['timezone'] ?? timezone)
          .toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    const zones = [
      'Asia/Bangkok',
      'Asia/Shanghai',
      'Asia/Hong_Kong',
      'Asia/Singapore',
      'Asia/Tokyo',
      'Asia/Seoul',
      'Asia/Ho_Chi_Minh',
      'Asia/Kolkata',
      'Asia/Dubai',
      'Europe/London',
      'Europe/Paris',
      'America/New_York',
      'America/Chicago',
      'America/Los_Angeles',
      'Australia/Sydney',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(s.birth, s.birthIntro),
            FateCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: name,
                    maxLength: 60,
                    decoration: InputDecoration(
                      labelText: s.nickname,
                      hintText: s.nicknamePlaceholder,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(s.birthDate),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: pending
                        ? null
                        : () async {
                            final next = await showModalBottomSheet<String>(
                              context: context,
                              isScrollControlled: true,
                              useRootNavigator: true,
                              useSafeArea: true,
                              constraints: const BoxConstraints(maxWidth: 430),
                              backgroundColor: panelColor,
                              builder: (_) => _DateSheet(value: date),
                            );
                            if (next != null && mounted) {
                              setState(() => date = next);
                            }
                          },
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 19),
                        const SizedBox(width: 12),
                        Expanded(child: Text(date ?? s.chooseBirthDate)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(s.birthTime),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: unknown || pending
                        ? null
                        : () async {
                            final current = time?.split(':');
                            final next = await showTimePicker(
                              context: context,
                              initialTime: current == null
                                  ? const TimeOfDay(hour: 12, minute: 0)
                                  : TimeOfDay(
                                      hour: int.parse(current[0]),
                                      minute: int.parse(current[1]),
                                    ),
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(
                                  context,
                                ).copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (next != null && mounted) {
                              setState(
                                () => time =
                                    '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}',
                              );
                            }
                          },
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 19),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            unknown ? s.timeUnknown : time ?? s.chooseBirthTime,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: unknown,
                    onChanged: pending
                        ? null
                        : (value) => setState(() => unknown = value!),
                    title: Text(
                      s.timeUnknown,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (unknown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        s.unknownTime,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  TextFormField(
                    controller: place,
                    decoration: InputDecoration(
                      labelText: s.birthplace,
                      hintText: s.birthplacePlaceholder,
                    ),
                    maxLength: 100,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? s.placeRequired
                        : null,
                    onChanged: (_) => placeId = null,
                  ),
                  TextButton.icon(
                    onPressed: pending ? null : chooseCity,
                    icon: const Icon(Icons.search, size: 18),
                    label: Text(s.cityDirectory),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(timezone),
                    initialValue: timezone,
                    decoration: InputDecoration(labelText: s.timezone),
                    isExpanded: true,
                    items: {timezone, ...zones}
                        .map(
                          (zone) => DropdownMenuItem(
                            value: zone,
                            child: Text(
                              zone,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: pending
                        ? null
                        : (value) => setState(() => timezone = value!),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    s.birthStorage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: pending ? null : save,
              child: Text(pending ? s.waiting : s.saveBirth),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    name.dispose();
    place.dispose();
    super.dispose();
  }
}

class _DateSheet extends StatefulWidget {
  const _DateSheet({this.value});
  final String? value;
  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late int year, month, day;
  bool buddhist = false;
  late FixedExtentScrollController years, months, days;
  @override
  void initState() {
    super.initState();
    final initial =
        DateTime.tryParse(widget.value ?? '') ?? DateTime(1999, 1, 1);
    year = initial.year;
    month = initial.month;
    day = initial.day;
    years = FixedExtentScrollController(initialItem: year - 1901);
    months = FixedExtentScrollController(initialItem: month - 1);
    days = FixedExtentScrollController(initialItem: day - 1);
  }

  int get maxDay => DateTime(year, month + 1, 0).day;
  void update(VoidCallback change) {
    setState(() {
      change();
      day = min(day, maxDay);
    });
    if (days.hasClients && days.selectedItem >= maxDay) {
      days.jumpToItem(day - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), today = DateTime.now();
    final chosen = DateTime(year, month, day);
    final allowed = !chosen.isAfter(
      DateTime(today.year, today.month, today.day),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.birthDate, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(s.calendarGregorian)),
                ButtonSegment(value: true, label: Text(s.calendarBuddhist)),
              ],
              selected: {buddhist},
              onSelectionChanged: (v) => setState(() => buddhist = v.first),
            ),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: CupertinoPicker(
                      scrollController: years,
                      itemExtent: 42,
                      onSelectedItemChanged: (i) =>
                          update(() => year = i + 1901),
                      children: [
                        for (var y = 1901; y <= today.year; y++)
                          Center(
                            child: Text(
                              '${y + (buddhist ? 543 : 0)}',
                              style: const TextStyle(
                                color: inkColor,
                                fontSize: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: months,
                      itemExtent: 42,
                      onSelectedItemChanged: (i) => update(() => month = i + 1),
                      children: [
                        for (var m = 1; m <= 12; m++)
                          Center(
                            child: Text(
                              '$m',
                              style: const TextStyle(
                                color: inkColor,
                                fontSize: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: days,
                      itemExtent: 42,
                      onSelectedItemChanged: (i) => setState(() => day = i + 1),
                      children: [
                        for (var n = 1; n <= maxDay; n++)
                          Center(
                            child: Text(
                              '$n',
                              style: const TextStyle(
                                color: inkColor,
                                fontSize: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: allowed
                  ? () => Navigator.pop(
                      context,
                      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
                    )
                  : null,
              child: Text(s.pickerDone),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    years.dispose();
    months.dispose();
    days.dispose();
    super.dispose();
  }
}

class _CitySheet extends StatefulWidget {
  const _CitySheet({
    required this.search,
    required this.title,
    required this.hint,
    required this.errorText,
  });
  final Future<List<Map<String, dynamic>>> Function(String, String) search;
  final String title, hint, errorText;
  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  final query = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  bool busy = false, failed = false;
  bool searched = false;
  String country = 'TH';
  int generation = 0;
  Future<void> search() async {
    if (query.text.trim().length < 2) return;
    final current = ++generation;
    setState(() {
      busy = true;
      failed = false;
      searched = true;
    });
    try {
      final next = await widget.search(query.text.trim(), country);
      if (mounted && current == generation) setState(() => rows = next);
    } catch (_) {
      if (mounted && current == generation) setState(() => failed = true);
    } finally {
      if (mounted && current == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom -
                    100)
                .clamp(180, 400)
                .toDouble(),
        child: Column(
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: country,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).country,
              ),
              items:
                  {
                        'TH': AppLocalizations.of(context).countryTH,
                        'CN': AppLocalizations.of(context).countryCN,
                        'VN': AppLocalizations.of(context).countryVN,
                        'US': AppLocalizations.of(context).countryUS,
                      }.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value == null) return;
                ++generation;
                setState(() {
                  country = value;
                  rows = [];
                  busy = false;
                  searched = false;
                  failed = false;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: query,
              onSubmitted: (_) => search(),
              decoration: InputDecoration(
                hintText: widget.hint,
                suffixIcon: IconButton(
                  onPressed: busy ? null : search,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            if (failed) Text(widget.errorText),
            if (searched && !busy && !failed && rows.isEmpty)
              Text(
                AppLocalizations.of(context).noCityResults,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final row in rows)
                    ListTile(
                      title: Text(
                        (row['display_name'] ??
                                row['name'] ??
                                row['label'] ??
                                '')
                            .toString(),
                      ),
                      subtitle: Text(
                        (row['timezone'] ?? row['tzid'] ?? '').toString(),
                      ),
                      onTap: () => Navigator.pop(context, row),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  void dispose() {
    ++generation;
    query.dispose();
    super.dispose();
  }
}
