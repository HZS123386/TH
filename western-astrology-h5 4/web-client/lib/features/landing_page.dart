import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../app/languages.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';
import '../ui/jy_components.dart';
import '../ui/site_header.dart';
import 'birth_date_dialog.dart';
import 'generation_dialog.dart';
import 'history_dialog.dart';
import 'place_picker.dart';
import 'support_content.dart';

enum _BirthFormProgress { empty, date, time, place, complete }

const _footerLinkStyle = TextStyle(
  fontSize: 10,
  decoration: TextDecoration.underline,
);

class LandingPage extends StatefulWidget {
  const LandingPage({this.topic = 'life', super.key});
  final String topic;
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with WidgetsBindingObserver {
  static const _stages = ['unspecified', 'considering', 'searching', 'offer'];
  String _date = '', _time = '', _error = '';
  bool _unknown = false,
      _custom = false,
      _restored = false,
      _restoringCareer = false;
  Place? _place;
  String? _question;
  final _questionText = TextEditingController();
  bool get _marriageMode => widget.topic != 'career' && !_restoringCareer;
  late final _questionPages = PageController(
    initialPage: _stages.indexOf(_question ?? '').clamp(0, _stages.length - 1),
  );
  CancelToken? _request;
  GenerationState? _generation;
  bool _recordedPage = false;
  bool _resumeChecked = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final h5 = H5Scope.of(context);
    if (!_restored) {
      _restored = true;
      final input = h5.landingInput;
      if (input != null) {
        final profile = object(input['profile']);
        _date = text(profile['birth_date']);
        _time = text(profile['birth_time']);
        _unknown = _time.isEmpty;
        _place = h5.landingPlace;
        final stage = text(object(input['career_question'])['stage']);
        _question = _stages.contains(stage) ? stage : null;
        _restoringCareer = _question != null;
        if (!_marriageMode) {
          _questionText.text = text(input['user_question']);
          _custom = _questionText.text.isNotEmpty;
        }
      }
    }
    if (_place?.country != h5BirthCountry(h5.language)) _place = null;
    if (!_resumeChecked) {
      _resumeChecked = true;
      final saved =
          h5.browser.readSetting('active-preview', session: true) ?? '';
      if (RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(saved)) {
        h5.browser.writeSetting('active-preview', '', session: true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/report.html?id=$saved&lang=${h5.language}');
        });
      }
    }
    unawaited(h5.recordVisit());
    if (!_recordedPage && !h5.welcomeOpen) {
      _recordedPage = true;
      h5.trackActivity('birth_form');
      _recordFormProgress(h5);
    }
  }

  @override
  void dispose() {
    _request?.cancel();
    _questionText.dispose();
    _questionPages.dispose();
    super.dispose();
  }

  Future<void> _datePicker(H5Controller h5) async {
    h5.trackActivity('birth_form', 'select_birth_date');
    final value = await chooseBirthDate(
      context,
      h5.copy,
      _date,
      h5.browser.today(_place?.zone ?? 'Asia/Bangkok'),
    );
    if (!mounted) return;
    if (value != null) setState(() => _date = value);
    _recordFormProgress(h5);
  }

  Future<void> _timePicker(H5Controller h5) async {
    final current = _time.split(':');
    h5.trackActivity('birth_form', 'select_birth_time');
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
    if (!mounted) return;
    if (value != null) {
      setState(
        () => _time =
            '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
      );
    }
    _recordFormProgress(h5);
  }

  void _setUnknownTime(H5Controller h5, bool value) {
    if (_unknown == value) return;
    setState(() => _unknown = value);
    _recordFormProgress(h5);
  }

  _BirthFormProgress _formProgress(H5Controller h5) {
    if (_date.isEmpty && _time.isEmpty && !_unknown && _place == null) {
      return _BirthFormProgress.empty;
    }
    if (!validBirthDate(
      _date,
      h5.browser.today(_place?.zone ?? 'Asia/Bangkok'),
    )) {
      return _BirthFormProgress.date;
    }
    if (!_unknown && _time.isEmpty) return _BirthFormProgress.time;
    if (_place?.country != h5BirthCountry(h5.language)) {
      return _BirthFormProgress.place;
    }
    return _BirthFormProgress.complete;
  }

  void _recordFormProgress(H5Controller h5, [_BirthFormProgress? checked]) {
    final progress = checked ?? _formProgress(h5);
    h5.trackActivity('birth_form', 'form_progress_${progress.name}');
  }

  Json _input(H5Controller h5) {
    final start = h5.browser.today('Asia/Bangkok');
    final previous = object(h5.landingInput?['profile']);
    final samePlace =
        h5.landingPlace != null &&
        _place!.id == h5.landingPlace!.id &&
        _place!.zone == h5.landingPlace!.zone;
    return {
      'report_kind': _marriageMode ? 'marriage' : 'fortune',
      'profile': {
        'display_name': '',
        'birth_date': _date,
        'birth_time': _unknown ? null : _time,
        'birthplace': samePlace && text(previous['birthplace']).isNotEmpty
            ? previous['birthplace']
            : '${_place!.english}, ${_place!.country}',
        'timezone': _place!.zone,
        'language': h5.language,
        'country_code': _place!.country.isEmpty ? null : _place!.country,
        'location_id': _place!.id.isEmpty ? null : _place!.id,
        // Keep original coordinates until the user selects a different location.
        'latitude': samePlace ? previous['latitude'] : null,
        'longitude': samePlace ? previous['longitude'] : null,
      },
      'year': !_marriageMode && _question != null && !_custom
          ? int.parse(start.substring(0, 4))
          : DateTime.now().year,
      if (!_marriageMode && _question != null && !_custom)
        'career_question': {'stage': _question, 'start': start},
      if (!_marriageMode && _custom && _questionText.text.trim().isNotEmpty)
        'user_question': _questionText.text.trim(),
    };
  }

  Future<void> _generate(H5Controller h5) async {
    if (_generation != null) return;
    final c = h5.copy;
    final progress = _formProgress(h5);
    _recordFormProgress(h5, progress);
    final errorKey = switch (progress) {
      _BirthFormProgress.empty || _BirthFormProgress.date => 'invalidDate',
      _BirthFormProgress.time => 'timeRequired',
      _BirthFormProgress.place => 'invalidPlace',
      _BirthFormProgress.complete => null,
    };
    if (errorKey != null) {
      setState(() => _error = c.t('ui', errorKey));
      h5.trackActivity('birth_form', 'invalid_form');
      return;
    }
    setState(() => _error = '');
    final input = _input(h5);
    final state = GenerationState();
    _generation = state;
    h5.warmReportFont();
    var attempts = 0;
    Future<void> run() async {
      _request?.cancel();
      final token = CancelToken();
      _request = token;
      state.retry();
      h5.trackActivity(
        'generating_preview',
        attempts++ == 0 ? 'generate' : 'retry_generation',
      );
      try {
        final report = await h5.repository.generate(input, token, (
          report,
          percent,
          phase,
        ) {
          state.update(report, percent, phase);
          h5.browser.writeSetting('active-preview', report.id, session: true);
          unawaited(h5.trackReport(report.id, 'submitted'));
        }, visit: h5.browser.visitContext());
        await h5.prepareText(
          jsonEncode(report.json),
          language: report.language,
        );
        if (mounted && !token.cancelled) state.ready(report);
      } catch (error) {
        if (mounted && !token.cancelled) {
          state.fail(h5.message(error));
          h5.trackActivity('generating_preview', 'generation_failed');
        }
      }
    }

    unawaited(run());
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (context, animation, secondaryAnimation) => GenerationDialog(
          h5: h5,
          state: state,
          full: false,
          input: input,
          onCancel: () {
            _request?.cancel();
            h5.browser.writeSetting('active-preview', '', session: true);
            h5.trackActivity('birth_form', 'cancel_generation');
            Navigator.of(context, rootNavigator: true).pop();
          },
          onRetry: () => unawaited(run()),
          onComplete: (report) {
            h5.stageGeneratedPreview(report);
            h5.browser.writeSetting('active-preview', '', session: true);
            Navigator.of(context, rootNavigator: true).pop();
            context.go(
              '/report.html?id=${Uri.encodeComponent(report.id)}&lang=${report.language}',
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
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth <= 360;
        final wide = box.maxWidth >= 700;
        final margin = wide
            ? 32.0
            : compact
            ? 12.0
            : 17.0;
        final padding = wide
            ? 28.0
            : compact
            ? 16.0
            : 20.0;
        final portraitWidth = box.maxWidth.clamp(0.0, h5PortraitMaxWidth);
        final heroHeight = landingHeroHeight(box.maxWidth);
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
                      left: (box.maxWidth - portraitWidth) / 2,
                      width: portraitWidth,
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
                      c.t('jy', 'formTitle'),
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
                        Expanded(
                          child: Text(
                            c.t('jy', 'date'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.t('jy', 'calendar'),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 10,
                              color: lavender,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _field(
                      'birth-date',
                      birthDateLabel(_date, c.language),
                      c.t('jy', 'dateParts.placeholder'),
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
                                onTap: () => _setUnknownTime(h5, !_unknown),
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
                                              _setUnknownTime(h5, value!),
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
                      _unknown ? null : () => _timePicker(h5),
                    ),
                    const SizedBox(height: 13),
                    BirthplaceFields(
                      key: ValueKey('birthplace-${h5.language}'),
                      h5: h5,
                      country: h5BirthCountry(h5.language),
                      initialPlace: _place,
                      onSelected: (place) {
                        if (place == null && _place == null) return;
                        setState(() => _place = place);
                        _recordFormProgress(h5);
                      },
                    ),
                    if (!_marriageMode) ...[
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
                                              _question == _stages[index]
                                              ? null
                                              : _stages[index],
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
                                                        _question ==
                                                            _stages[index]
                                                        ? gold
                                                        : cream,
                                                  ),
                                                ),
                                              ),
                                              if (_question == _stages[index])
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
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: gold,
                                ),
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
                    ],
                    errorMessage(_error),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          c.t('jy', 'birthDataNotice'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: lavender),
                        ),
                        TextButton(
                          onPressed: () => h5.browser.openPage(
                            'privacy.html?lang=${h5.language}',
                          ),
                          child: Text(
                            c.t('jy', 'privacy'),
                            style: _footerLinkStyle,
                          ),
                        ),
                      ],
                    ),
                    JYButton(
                      key: const ValueKey('generate-report'),
                      label: c.t('jy', 'topics.${widget.topic}.action'),
                      icon: 'book',
                      bounce: true,
                      onPressed: h5.languageLoading
                          ? null
                          : () => _generate(h5),
                    ),
                    const SizedBox(height: 19),
                    ThemeBoards(copy: c, viewportHeight: box.maxHeight),
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
                    _footerLinks(h5, box.maxWidth - 36),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _footerLinks(H5Controller h5, double availableWidth) {
    final c = h5.copy;
    final privacy = c.t('jy', 'privacy'), support = c.t('jy', 'support');
    final links = [
      TextButton(
        onPressed: () => context.go('/privacy.html?lang=${h5.language}'),
        child: Text(privacy, style: _footerLinkStyle),
      ),
      TextButton(
        onPressed: () => context.go('/support.html?lang=${h5.language}'),
        child: Text(support, style: _footerLinkStyle),
      ),
      for (final policy in PurchasePolicy.values)
        PurchasePolicyLink(policy, h5: h5, textStyle: _footerLinkStyle),
    ];
    final labels = [
      privacy,
      support,
      for (final policy in PurchasePolicy.values)
        c.t('purchasePolicies', policy.name),
    ];
    const dividerWidth = 6.0;
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelLarge!.merge(_footerLinkStyle);
    var rowWidth = dividerWidth * (links.length - 1);
    // Material 3 text buttons use a 64 px minimum width and 24 px horizontal padding.
    for (final label in labels) {
      final width = TextPainter.computeMaxIntrinsicWidth(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      );
      rowWidth += (width + 24).clamp(64.0, double.infinity);
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (index, link) in links.indexed) ...[
          if (index > 0 && rowWidth <= availableWidth)
            const ExcludeSemantics(
              child: SizedBox(
                width: dividerWidth,
                child: Text(
                  '|',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xA6E4BC78)),
                ),
              ),
            ),
          link,
        ],
      ],
    );
  }
}
