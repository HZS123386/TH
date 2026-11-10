import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/models.dart';

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
    final maxMonth = _date.year == _today.year ? _today.month : 12;
    final maxDay = _date.year == _today.year && _date.month == _today.month
        ? _today.day
        : DateTime(_date.year, _date.month + 1, 0).day;
    return AlertDialog(
      title: Text(
        '${widget.copy.t('ui', 'date')} · ${widget.copy.t('ui', 'ce')}',
      ),
      content: SizedBox(
        width: 370,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<int>(
                initialValue: _date.year,
                decoration: InputDecoration(labelText: zh ? '年' : 'ปี ค.ศ.'),
                isExpanded: true,
                items: [
                  for (var year = _today.year; year >= 1901; year--)
                    DropdownMenuItem(value: year, child: Text('$year')),
                ],
                onChanged: (v) => _update(v!, _date.month, _date.day),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<int>(
                key: ValueKey('month-${_date.year}'),
                initialValue: _date.month,
                isExpanded: true,
                decoration: InputDecoration(labelText: zh ? '月' : 'เดือน'),
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
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                key: ValueKey('day-${_date.year}-${_date.month}'),
                initialValue: _date.day,
                decoration: InputDecoration(labelText: zh ? '日' : 'วัน'),
                items: [
                  for (var day = 1; day <= maxDay; day++)
                    DropdownMenuItem(value: day, child: Text('$day')),
                ],
                onChanged: (v) => _update(_date.year, _date.month, v!),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.copy.t('ui', 'close')),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, DateFormat('yyyy-MM-dd').format(_date)),
          child: Text(widget.copy.t('ui', 'confirm')),
        ),
      ],
    );
  }
}
