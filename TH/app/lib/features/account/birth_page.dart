import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../core/models/birth_profile.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import 'birthplace_fields.dart';

class BirthPage extends StatefulWidget {
  const BirthPage({
    this.returnToPrevious = false,
    this.openThaiChart = false,
    this.header,
    super.key,
  });
  final bool returnToPrevious;
  final bool openThaiChart;
  final Widget? header;
  @override
  State<BirthPage> createState() => _BirthPageState();
}

class _BirthPageState extends State<BirthPage> {
  final formKey = GlobalKey<FormState>();
  BirthProfile? original;
  Map<String, dynamic>? birthLocation;
  String? date, time;
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
      date = p.date;
      time = p.time;
      unknown = p.time == null;
    }
  }

  Future<void> save() async {
    final s = AppLocalizations.of(context),
        session = DependencyScope.of(context).session;
    if (_formOwner == 'guest' && session.auth.isGuest) {
      _formOwner = session.owner;
    }
    if (_formOwner != session.owner) {
      setState(() => error = s.error);
      return;
    }
    if (pending || !formKey.currentState!.validate()) return;
    final location = birthLocation;
    if (location == null) {
      setState(() => error = s.selectBirthCity);
      return;
    }
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
          timezone: (location['timeZone'] ?? location['timezone']) as String,
          place: '${location['nameEnglish']}, ${location['countryCode']}',
          name: original?.name ?? '',
          placeId: location['id'] as String,
          countryCode: location['countryCode'] as String,
          latitude: (location['latitude'] as num).toDouble(),
          longitude: (location['longitude'] as num).toDouble(),
          id: original?.id,
          revision: original?.revision,
        ),
      );
      if (mounted) {
        if (session.thaiAstrologyOnly) {
          context.go('/chart/thai');
        } else if (widget.openThaiChart) {
          context.pushReplacement('/chart/thai');
        } else if (widget.returnToPrevious && context.canPop()) {
          context.pop();
        } else {
          context.go('/chart');
        }
      }
    } catch (_) {
      if (mounted) setState(() => error = s.error);
    } finally {
      if (mounted) {
        if (_formOwner == 'guest' && session.auth.isGuest) {
          _formOwner = session.owner;
        }
        setState(() => pending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final thaiOnly = DependencyScope.of(context).session.thaiAstrologyOnly;
    final form = Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(s.birth, s.birthIntro),
          if (thaiOnly) ...[
            TextButton.icon(
              onPressed: () => context.push('/privacy'),
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: Text(s.privacyCenter),
            ),
            const SizedBox(height: 8),
          ],
          FateCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.birthDate),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: pending
                      ? null
                      : () async {
                          final next = await showModalBottomSheet<String>(
                            context: context,
                            sheetAnimationStyle: FateMotion.dialog(context),
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
                BirthplaceFields(
                  repository: DependencyScope.of(context).session.profiles,
                  initialProfile: original,
                  enabled: !pending,
                  onSelected: (value) => setState(() => birthLocation = value),
                ),
                const SizedBox(height: 20),
                Text(
                  thaiOnly ? s.thaiBirthStorage : s.birthStorage,
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
          SizedBox(
            width: thaiOnly ? double.infinity : null,
            child: FilledButton(
              onPressed: pending ? null : save,
              child: Text(pending ? s.waiting : s.saveBirth),
            ),
          ),
          if (!thaiOnly)
            TextButton(
              onPressed: pending ? null : () => context.go('/chart?example=1'),
              child: Text(s.example),
            ),
        ],
      ),
    );
    final header = widget.header;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: header == null
          ? form
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final sideBySide = width >= 680;
                const gap = 24.0;
                final chartWidth = sideBySide ? (width - gap) * .42 : width;
                return Flex(
                  direction: sideBySide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: gap,
                  children: [
                    SizedBox(width: chartWidth, child: header),
                    SizedBox(
                      width: sideBySide ? width - chartWidth - gap : width,
                      child: form,
                    ),
                  ],
                );
              },
            ),
    );
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
    final textHeight = MediaQuery.textScalerOf(context).scale(18) * 1.45;
    final itemExtent = max(42.0, textHeight);
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.birthDate, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 16),
              Text(
                s.calendarGregorian,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(
                height: min(
                  220.0,
                  max(itemExtent, constraints.maxHeight - 168),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _picker(
                        years,
                        1901,
                        today.year,
                        itemExtent,
                        (value) => update(() => year = value),
                      ),
                    ),
                    Expanded(
                      child: _picker(
                        months,
                        1,
                        12,
                        itemExtent,
                        (value) => update(() => month = value),
                      ),
                    ),
                    Expanded(
                      child: _picker(
                        days,
                        1,
                        maxDay,
                        itemExtent,
                        (value) => setState(() => day = value),
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
      ),
    );
  }

  Widget _picker(
    FixedExtentScrollController controller,
    int first,
    int last,
    double itemExtent,
    ValueChanged<int> onChanged,
  ) => CupertinoPicker.builder(
    scrollController: controller,
    itemExtent: itemExtent,
    childCount: last - first + 1,
    onSelectedItemChanged: (index) => onChanged(first + index),
    itemBuilder: (_, index) => Center(
      child: Text(
        '${first + index}',
        style: const TextStyle(color: inkColor, fontSize: 18),
      ),
    ),
  );

  @override
  void dispose() {
    years.dispose();
    months.dispose();
    days.dispose();
    super.dispose();
  }
}
