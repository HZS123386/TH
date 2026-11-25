import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../app/languages.dart';
import '../core/models.dart';
import '../ui/theme.dart';

String birthDateLabel(String value, String language) {
  final date = DateTime.tryParse(value);
  return date == null
      ? value
      : DateFormat.yMMMd(h5DateLocale(language)).format(date);
}

Future<String?> chooseBirthDate(
  BuildContext context,
  Copy copy,
  String value,
  String today,
) => showDialog<String>(
  context: context,
  builder: (_) => BirthDateDialog(copy: copy, value: value, today: today),
);

class BirthDateDialog extends StatefulWidget {
  const BirthDateDialog({
    required this.copy,
    required this.value,
    required this.today,
    super.key,
  });
  final Copy copy;
  final String value, today;
  @override
  State<BirthDateDialog> createState() => _BirthDateDialogState();
}

class _BirthDateDialogState extends State<BirthDateDialog> {
  static const _firstYear = 1901;
  late final _today = DateTime.parse(widget.today);
  late final _lastDate = _today.year > 2099 ? DateTime(2099, 12, 31) : _today;
  late DateTime _date = validBirthDate(widget.value, widget.today)
      ? DateTime.parse(widget.value)
      : _defaultDate();

  DateTime _defaultDate() {
    final year = math.min(1990, _lastDate.year);
    final month = math.min(7, _lastMonth(year));
    final day = math.min(15, _lastDay(year, month));
    return DateTime(year, month, day);
  }

  int _lastMonth(int year) => year == _lastDate.year ? _lastDate.month : 12;

  int _lastDay(int year, int month) =>
      year == _lastDate.year && month == _lastDate.month
      ? _lastDate.day
      : DateTime(year, month + 1, 0).day;

  void _update(int year, int month, int day) {
    final validMonth = month.clamp(1, _lastMonth(year));
    final validDay = day.clamp(1, _lastDay(year, validMonth));
    setState(() => _date = DateTime(year, validMonth, validDay));
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;
    final zh = copy.language == 'zh';
    final monthFormat = DateFormat.MMM(h5DateLocale(copy.language));
    final yearLabel = copy.t('jy', 'dateParts.year');
    final dayLabel = copy.t('jy', 'dateParts.day');
    final lastMonth = _lastMonth(_date.year);
    final lastDay = _lastDay(_date.year, _date.month);
    return _BirthWheelDialog(
      copy: copy,
      title: copy.t('ui', 'date'),
      onConfirm: () =>
          Navigator.pop(context, DateFormat('yyyy-MM-dd').format(_date)),
      wheels: [
        _PickerWheel(
          label: yearLabel,
          index: _date.year - _firstYear,
          count: _lastDate.year - _firstYear + 1,
          text: (index) => '${_firstYear + index}${zh ? yearLabel : ''}',
          onChanged: (index) =>
              _update(_firstYear + index, _date.month, _date.day),
        ),
        // Recenter linked wheels when a shorter month or the current year changes their range.
        _PickerWheel(
          key: ValueKey(('month', lastMonth)),
          label: copy.t('jy', 'dateParts.month'),
          index: _date.month - 1,
          count: lastMonth,
          text: (index) => monthFormat.format(DateTime(2000, index + 1)),
          onChanged: (index) => _update(_date.year, index + 1, _date.day),
        ),
        _PickerWheel(
          key: ValueKey(('day', lastDay)),
          label: dayLabel,
          index: _date.day - 1,
          count: lastDay,
          text: (index) => '${index + 1}${zh ? dayLabel : ''}',
          onChanged: (index) => _update(_date.year, _date.month, index + 1),
        ),
      ],
    );
  }
}

Future<TimeOfDay?> chooseBirthTime(
  BuildContext context,
  Copy copy,
  TimeOfDay value,
) => showDialog<TimeOfDay>(
  context: context,
  builder: (_) => _BirthTimeDialog(copy: copy, value: value),
);

class _BirthTimeDialog extends StatefulWidget {
  const _BirthTimeDialog({required this.copy, required this.value});

  final Copy copy;
  final TimeOfDay value;

  @override
  State<_BirthTimeDialog> createState() => _BirthTimeDialogState();
}

class _BirthTimeDialogState extends State<_BirthTimeDialog> {
  late int _hourIndex = (widget.value.hour + 11) % 12;
  late int _minute = widget.value.minute;
  late DayPeriod _period = widget.value.period;

  @override
  Widget build(BuildContext context) {
    final strings = MaterialLocalizations.of(context);
    final am = strings.anteMeridiemAbbreviation;
    final pm = strings.postMeridiemAbbreviation;
    return _BirthWheelDialog(
      copy: widget.copy,
      title: widget.copy.t('ui', 'time'),
      onConfirm: () => Navigator.pop(
        context,
        TimeOfDay(
          hour: (_hourIndex + 1) % 12 + (_period == DayPeriod.pm ? 12 : 0),
          minute: _minute,
        ),
      ),
      wheels: [
        _PickerWheel(
          label: strings.timePickerHourLabel,
          index: _hourIndex,
          count: 12,
          text: (index) => strings.formatDecimal(index + 1),
          onChanged: (index) => setState(() => _hourIndex = index),
        ),
        _PickerWheel(
          label: strings.timePickerMinuteLabel,
          index: _minute,
          count: 60,
          text: (index) =>
              strings.formatMinute(TimeOfDay(hour: 0, minute: index)),
          onChanged: (index) => setState(() => _minute = index),
        ),
        _PickerWheel(
          label: '$am / $pm',
          index: _period.index,
          count: DayPeriod.values.length,
          text: (index) => index == DayPeriod.am.index ? am : pm,
          onChanged: (index) =>
              setState(() => _period = DayPeriod.values[index]),
        ),
      ],
    );
  }
}

double _itemExtent(BuildContext context) =>
    math.max(42, MediaQuery.textScalerOf(context).scale(20) * 1.45);

class _BirthWheelDialog extends StatelessWidget {
  const _BirthWheelDialog({
    required this.copy,
    required this.title,
    required this.onConfirm,
    required this.wheels,
  });

  final Copy copy;
  final String title;
  final VoidCallback onConfirm;
  final List<Widget> wheels;

  @override
  Widget build(BuildContext context) {
    final extent = _itemExtent(context);
    final scrollBehavior = ScrollConfiguration.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 400),
      backgroundColor: panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: gold.withValues(alpha: .24)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cream,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height:
                    extent *
                    (constraints.maxHeight >= extent * 5 + 155 ? 5 : 3),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      height: extent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: gold.withValues(alpha: .55),
                          ),
                        ),
                      ),
                    ),
                    ScrollConfiguration(
                      behavior: scrollBehavior.copyWith(
                        scrollbars: false,
                        dragDevices: {
                          ...scrollBehavior.dragDevices,
                          PointerDeviceKind.mouse,
                        },
                      ),
                      child: Row(
                        children: [
                          for (final wheel in wheels) Expanded(child: wheel),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onConfirm,
                child: Text(copy.t('ui', 'confirm')),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: lavender),
                  child: Text(copy.t('ui', 'close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerWheel extends StatefulWidget {
  const _PickerWheel({
    required this.label,
    required this.index,
    required this.count,
    required this.text,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int index, count;
  final String Function(int) text;
  final ValueChanged<int> onChanged;

  @override
  State<_PickerWheel> createState() => _PickerWheelState();
}

class _PickerWheelState extends State<_PickerWheel> {
  late final _controller = FixedExtentScrollController(
    initialItem: widget.index,
  );
  bool _focused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if ((event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        !_controller.hasClients) {
      return KeyEventResult.ignored;
    }
    final current = _controller.selectedItem;
    final target = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => current - 1,
      LogicalKeyboardKey.arrowDown => current + 1,
      LogicalKeyboardKey.pageUp => current - 10,
      LogicalKeyboardKey.pageDown => current + 10,
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => widget.count - 1,
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    _controller.jumpToItem(target.clamp(0, widget.count - 1));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    container: true,
    child: Focus(
      onKeyEvent: _onKey,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: _focused ? Border.all(color: gold) : null,
        ),
        child: CupertinoPicker.builder(
          scrollController: _controller,
          itemExtent: _itemExtent(context),
          diameterRatio: 3,
          squeeze: 1,
          selectionOverlay: null,
          childCount: widget.count,
          onSelectedItemChanged: widget.onChanged,
          itemBuilder: (context, index) {
            final selected = index == widget.index;
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.text(index),
                    style: TextStyle(
                      fontFamily: h5FontFamily,
                      fontFamilyFallback: h5FontFallback,
                      fontSize: 20,
                      color: selected ? gold : lavender,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
