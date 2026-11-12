import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/models.dart';
import '../ui/theme.dart';

String birthDateLabel(String value, String language) {
  final date = DateTime.tryParse(value);
  return date == null ? value : DateFormat.yMMMd(language).format(date);
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
  late DateTime _date = DateTime.tryParse(widget.value) ?? DateTime(1999, 1, 1);
  late final _today = DateTime.parse(widget.today);
  void _update(int year, int month, int day) {
    final maxMonth = year == _today.year ? _today.month : 12;
    month = month.clamp(1, maxMonth);
    final maxDay = year == _today.year && month == _today.month
        ? _today.day
        : DateTime(year, month + 1, 0).day;
    setState(() => _date = DateTime(year, month, day.clamp(1, maxDay)));
  }

  @override
  Widget build(BuildContext context) {
    final zh = widget.copy.language == 'zh';
    const fieldStyle = TextStyle(
      fontFamily: h5FontFamily,
      fontFamilyFallback: h5FontFallback,
      color: cream,
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
    );
    final maxMonth = _date.year == _today.year ? _today.month : 12;
    final maxDay = _date.year == _today.year && _date.month == _today.month
        ? _today.day
        : DateTime(_date.year, _date.month + 1, 0).day;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      title: Text(
        widget.copy.t('ui', 'date'),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                key: const ValueKey('birth-year'),
                initialValue: _date.year,
                decoration: InputDecoration(
                  labelText: zh ? '年' : 'ปี ค.ศ.',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                isExpanded: true,
                menuMaxHeight: 280,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: gold,
                ),
                style: fieldStyle,
                items: [
                  for (var year = _today.year; year >= 1901; year--)
                    DropdownMenuItem(
                      value: year,
                      child: Text(zh ? '$year年' : '$year'),
                    ),
                ],
                onChanged: (v) => _update(v!, _date.month, _date.day),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('month-${_date.year}'),
                      initialValue: _date.month,
                      isExpanded: true,
                      menuMaxHeight: 280,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: gold,
                      ),
                      style: fieldStyle,
                      decoration: InputDecoration(
                        labelText: zh ? '月' : 'เดือน',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      items: [
                        for (var month = 1; month <= maxMonth; month++)
                          DropdownMenuItem(
                            value: month,
                            child: Text(
                              DateFormat.MMM(
                                widget.copy.language,
                              ).format(DateTime(2000, month)),
                            ),
                          ),
                      ],
                      onChanged: (v) => _update(_date.year, v!, _date.day),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('day-${_date.year}-${_date.month}'),
                      initialValue: _date.day,
                      isExpanded: true,
                      menuMaxHeight: 280,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: gold,
                      ),
                      style: fieldStyle,
                      decoration: InputDecoration(
                        labelText: zh ? '日' : 'วัน',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      items: [
                        for (var day = 1; day <= maxDay; day++)
                          DropdownMenuItem(
                            value: day,
                            child: Text(zh ? '$day日' : '$day'),
                          ),
                      ],
                      onChanged: (v) => _update(_date.year, _date.month, v!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                DateFormat('yyyy-MM-dd').format(_date),
              ),
              style: FilledButton.styleFrom(
                textStyle: const TextStyle(
                  fontFamily: h5FontFamily,
                  fontFamilyFallback: h5FontFallback,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(widget.copy.t('ui', 'confirm')),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size(88, 44),
                  foregroundColor: lavender,
                  textStyle: const TextStyle(
                    fontFamily: h5FontFamily,
                    fontFamilyFallback: h5FontFallback,
                    fontSize: 14,
                  ),
                ),
                child: Text(widget.copy.t('ui', 'close')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
