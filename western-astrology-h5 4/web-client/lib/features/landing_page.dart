import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';
import '../ui/jy_components.dart';
import '../ui/site_header.dart';
import 'birth_date_dialog.dart';
import 'generation_dialog.dart';
import 'history_dialog.dart';
import 'information_page.dart';
import 'place_picker.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({this.topic = 'life', super.key});
  final String topic;
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with WidgetsBindingObserver {
  String _date = '', _time = '', _error = '';
  bool _unknown = false, _custom = false, _confirming = false;
  Place? _place;
  String? _question;
  final _questionText = TextEditingController(),
      _questionPages = PageController();
  CancelToken? _request;
  GenerationState? _generation;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(H5Scope.of(context).recordVisit());
  }

  @override
  void dispose() {
    _request?.cancel();
    _questionText.dispose();
    _questionPages.dispose();
    super.dispose();
  }

  Future<void> _datePicker(H5Controller h5) async {
    final value = await chooseBirthDate(
      context,
      h5.copy,
      _date,
      h5.browser.today(_place?.zone ?? 'Asia/Bangkok'),
    );
    if (value != null && mounted) setState(() => _date = value);
  }

  Future<void> _timePicker() async {
    final current = _time.split(':');
    final value = await showTimePicker(
      context: context,
      initialTime: current.length == 2
          ? TimeOfDay(
              hour: int.parse(current[0]),
              minute: int.parse(current[1]),
            )
          : const TimeOfDay(hour: 7, minute: 15),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (value != null && mounted) {
      setState(
        () => _time =
            '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  Json _input(H5Controller h5) {
    final start = h5.browser.today('Asia/Bangkok');
    return {
      'report_kind': 'fortune',
      'profile': {
        'display_name': '',
        'birth_date': _date,
        'birth_time': _unknown ? null : _time,
        'birthplace': '${_place!.english}, ${_place!.country}',
        'timezone': _place!.zone,
        'language': h5.language,
        'country_code': _place!.country,
        'location_id': _place!.id,
        'latitude': null,
        'longitude': null,
      },
      'year': _question != null && !_custom
          ? int.parse(start.substring(0, 4))
          : DateTime.now().year,
      if (_question != null && !_custom)
        'career_question': {'stage': _question, 'start': start},
      if (_custom && _questionText.text.trim().isNotEmpty)
        'user_question': _questionText.text.trim(),
    };
  }

  Future<void> _generate(H5Controller h5) async {
    if (_generation != null || _confirming) return;
    final c = h5.copy;
    if (!validBirthDate(
      _date,
      h5.browser.today(_place?.zone ?? 'Asia/Bangkok'),
    )) {
      setState(() => _error = c.t('ui', 'invalidDate'));
      return;
    }
    if (!_unknown && _time.isEmpty) {
      setState(() => _error = c.t('ui', 'timeRequired'));
      return;
    }
    if (_place == null) {
      setState(() => _error = c.t('ui', 'invalidPlace'));
      return;
    }
    setState(() {
      _error = '';
      _confirming = true;
    });
    var accepted = false;
    try {
      accepted = await confirmDataUse(context, h5);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
    if (!mounted || !accepted) return;
    final input = _input(h5);
    final state = GenerationState();
    _generation = state;
    Future<void> run() async {
      _request?.cancel();
      final token = CancelToken();
      _request = token;
      state.retry();
      try {
        final report = await h5.repository.generate(input, token, (
          report,
          percent,
          phase,
        ) {
          state.update(report, percent, phase);
          unawaited(h5.trackReport(report.id, 'submitted'));
        });
        await h5.prepareText(
          jsonEncode(report.json),
          language: report.language,
        );
        if (mounted && !token.cancelled) state.ready(report);
      } catch (error) {
        if (mounted && !token.cancelled) state.fail(h5.message(error));
      }
    }

    unawaited(run());
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) => GenerationDialog(
          h5: h5,
          state: state,
          full: false,
          input: input,
          onCancel: () {
            _request?.cancel();
            Navigator.of(context, rootNavigator: true).pop();
          },
          onRetry: () => unawaited(run()),
          onComplete: (report) {
            Navigator.of(context, rootNavigator: true).pop();
            context.go(
              '/report.html?id=${Uri.encodeComponent(report.id)}&lang=${report.language}&checkout=1',
            );
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    _request?.cancel();
    if (_generation == state) _generation = null;
    state.dispose();
  }

  Widget _field(
    String id,
    String value,
    String hint,
    IconData icon,
    VoidCallback? action,
  ) => SizedBox(
    key: ValueKey(id),
    height: 46,
    child: Semantics(
      identifier: id,
      child: TextFormField(
        key: ValueKey('$id:$value'),
        readOnly: true,
        enabled: action != null,
        initialValue: value,
        style: const TextStyle(fontSize: 13),
        onTap: action,
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: Icon(icon, size: 18, color: lavender),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final h5 = H5Scope.of(context), c = h5.copy;
    final prompts = (c.value('jy', 'questions') as List).cast<List>();
    const stages = ['unspecified', 'considering', 'searching', 'offer'];
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth <= 360;
        final margin = compact ? 12.0 : 17.0, padding = compact ? 16.0 : 20.0;
        final heroHeight = compact
            ? 276.0
            : MediaQuery.sizeOf(context).width >= 700
            ? 326.0
            : 304.0;
        return SingleChildScrollView(
          key: const ValueKey('landing-scroll'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SiteHeader(),
              SizedBox(
                height: heroHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: -11,
                      child: Opacity(
                        opacity: h5.welcomeOpen && !h5.welcomePortraitRevealed
                            ? 0
                            : 1,
                        child: const AspectRatio(
                          aspectRatio: 1199 / 1312,
                          child: FateImage(
                            'assets/images/astrologer-900.webp',
                            fit: BoxFit.fitWidth,
                          ),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x0F130C24),
                              Color(0x66130C24),
                              night,
                            ],
                            stops: [.48, .78, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 15,
                      left: 17,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xB8190E35),
                          border: Border.all(color: const Color(0x70C6A1EA)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '✦  ${c.t('jy', 'persona')}',
                          style: const TextStyle(fontSize: 10.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(margin, 0, margin, 22),
                padding: EdgeInsets.fromLTRB(padding, 22, padding, 16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x70D5AE70)),
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF32203F),
                      Color(0xFF171023),
                      Color(0xFF211330),
                    ],
                    stops: [0, .7, 1],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66070310),
                      blurRadius: 34,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '✦  ${c.t('jy', 'formTitle')}  ✦',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                        color: gold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.t('jy', 'formCaption'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.7,
                        color: lavender,
                      ),
                    ),
                    const SizedBox(height: 17),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => showHistory(context, h5),
                        icon: const LandingIcon('history', size: 14),
                        label: Text(c.t('jy', 'history')),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text(
                          '☉',
                          style: TextStyle(color: gold, fontSize: 16),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          c.t('jy', 'date'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          c.t('jy', 'calendar'),
                          style: const TextStyle(fontSize: 10, color: lavender),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _field(
                      'birth-date',
                      _date,
                      c.language == 'zh' ? '年 / 月 / 日' : 'วัน / เดือน / ปี',
                      Icons.calendar_today_outlined,
                      () => _datePicker(h5),
                    ),
                    const SizedBox(height: 13),
                    LayoutBuilder(
                      builder: (context, box) => Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 3,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '◷',
                                style: TextStyle(color: gold, fontSize: 16),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                c.t('jy', 'time'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: box.maxWidth),
                            child: Semantics(
                              checked: _unknown,
                              label: c.t('jy', 'unknown'),
                              child: InkWell(
                                key: const ValueKey('birth-time-unknown'),
                                onTap: () =>
                                    setState(() => _unknown = !_unknown),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 16,
                                      child: Transform.scale(
                                        scale: .7,
                                        child: Checkbox(
                                          value: _unknown,
                                          onChanged: (value) =>
                                              setState(() => _unknown = value!),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        c.t('jy', 'unknown'),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: lavender,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    _field(
                      'birth-time',
                      _time,
                      '--:--',
                      Icons.schedule,
                      _unknown ? null : _timePicker,
                    ),
                    if (_unknown)
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          c.t('jy', 'unknownNote'),
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.8,
                            color: lavender,
                          ),
                        ),
                      ),
                    const SizedBox(height: 13),
                    BirthplaceFields(
                      h5: h5,
                      onSelected: (place) => setState(() => _place = place),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.t('jy', 'questionTitle'),
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.67,
                              color: gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            c.t('jy', 'questionHint'),
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.45,
                              color: lavender,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _custom
                              ? TextField(
                                  key: const ValueKey('custom-question'),
                                  controller: _questionText,
                                  maxLength: 120,
                                  style: const TextStyle(fontSize: 12),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.deny(
                                      RegExp(r'[\x00-\x1f\x7f]'),
                                      replacementString: ' ',
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: c.t('jy', 'questionTitle'),
                                    counterText: '',
                                  ),
                                )
                              : SizedBox(
                                  height: 44,
                                  child: PageView.builder(
                                    controller: _questionPages,
                                    scrollDirection: Axis.vertical,
                                    itemCount: 4,
                                    itemBuilder: (context, index) => InkWell(
                                      key: ValueKey('question-$index'),
                                      onTap: () => setState(
                                        () => _question =
                                            _question == stages[index]
                                            ? null
                                            : stages[index],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '${prompts[index][0]}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: gold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${prompts[index][1]}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  height: 1.4,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      _question == stages[index]
                                                      ? gold
                                                      : cream,
                                                ),
                                              ),
                                            ),
                                            if (_question == stages[index])
                                              Text(
                                                c.t('jy', 'selected'),
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: gold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        if (_custom)
                          TextButton(
                            onPressed: () => setState(() {
                              _custom = false;
                              _question = null;
                              _questionText.clear();
                            }),
                            child: Text(
                              c.t('jy', 'browseQuestions'),
                              style: const TextStyle(fontSize: 10, color: gold),
                            ),
                          )
                        else
                          SizedBox(
                            width: 84,
                            height: 46,
                            child: TextField(
                              readOnly: true,
                              key: const ValueKey('write-question'),
                              onTap: () => setState(() {
                                _custom = true;
                                _question = null;
                              }),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: c.t('jy', 'writeQuestion'),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    errorMessage(_error),
                    const SizedBox(height: 21),
                    JYButton(
                      key: const ValueKey('generate-report'),
                      label: c.t('jy', 'topics.${widget.topic}.action'),
                      icon: 'book',
                      bounce: true,
                      onPressed: h5.languageLoading || _confirming
                          ? null
                          : () => _generate(h5),
                    ),
                    const SizedBox(height: 19),
                    ThemeBoards(copy: c),
                    const SizedBox(height: 16),
                    Text(
                      c.t('jy', 'formHint'),
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.8,
                        color: lavender,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 3, 18, 28),
                child: Column(
                  children: [
                    Text(
                      c.t('jy', 'disclaimer'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: lavender),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () =>
                              context.go('/privacy.html?lang=${h5.language}'),
                          child: Text(
                            c.t('jy', 'privacy'),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.go('/support.html?lang=${h5.language}'),
                          child: Text(
                            c.t('jy', 'support'),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
