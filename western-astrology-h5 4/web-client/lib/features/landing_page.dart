import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';
import 'birth_date_dialog.dart';
import 'generation_dialog.dart';
import 'history_dialog.dart';
import 'information_page.dart';
import 'place_picker.dart';

const heroImage = AssetImage('assets/images/astrologer.webp');

class LandingPage extends StatefulWidget {
  const LandingPage({this.topic = 'life', super.key});
  final String topic;
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with WidgetsBindingObserver {
  String _date = '', _time = '', _country = '', _error = '';
  bool _unknown = false, _custom = false, _confirming = false;
  Place? _province, _place;
  String? _question;
  final _questionText = TextEditingController(),
      _questionPages = PageController();
  final _questionKey = GlobalKey();
  Timer? _rotation;
  int _questionIndex = 0, _direction = 1;
  DateTime _interaction = DateTime.fromMillisecondsSinceEpoch(0);
  CancelToken? _request;
  GenerationState? _generation;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rotation = Timer.periodic(
      const Duration(milliseconds: 3800),
      (_) => _rotate(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(H5Scope.of(context).recordVisit());
  }

  void _rotate() {
    if (!mounted ||
        _question != null ||
        _custom ||
        !_questionPages.hasClients ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        DateTime.now().difference(_interaction).inSeconds < 8) {
      return;
    }
    final box = _questionKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null ||
        !box.hasSize ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < 56 ||
        top + box.size.height > MediaQuery.sizeOf(context).height - 20) {
      return;
    }
    if (_questionIndex == 0) _direction = 1;
    if (_questionIndex == 3) _direction = -1;
    unawaited(
      _questionPages.animateToPage(
        _questionIndex + _direction,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _request?.cancel();
    _rotation?.cancel();
    _questionText.dispose();
    _questionPages.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _interaction = DateTime.now();
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

  Future<void> _countryPicker(H5Controller h5) async {
    final value = await chooseCountry(context, h5);
    if (value != null && mounted) {
      setState(() {
        _country = value;
        _province = null;
        _place = null;
      });
    }
  }

  Future<void> _provincePicker(H5Controller h5) async {
    if (_country.isEmpty) return;
    final value = await choosePlace(context, h5, _country);
    if (value != null && mounted) {
      setState(() {
        _province = value;
        _place = value;
      });
    }
  }

  Future<void> _cityPicker(H5Controller h5) async {
    if (_province == null) return;
    final value = await choosePlace(context, h5, _country, province: _province);
    if (value != null && mounted) setState(() => _place = value);
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
    setState(() => _error = '');
    _confirming = true;
    var accepted = false;
    try {
      accepted = await confirmDataUse(context, h5);
    } finally {
      _confirming = false;
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
        if (mounted && !token.cancelled) state.ready(report);
      } catch (error) {
        if (mounted && !token.cancelled) state.fail(h5.message(error));
      }
    }

    unawaited(run());
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => GenerationDialog(
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
            '/report.html?id=${Uri.encodeComponent(report.id)}&lang=${report.language}',
          );
        },
      ),
    );
    _request?.cancel();
    if (_generation == state) _generation = null;
    state.dispose();
  }

  Widget _field(
    String label,
    String value,
    IconData icon,
    VoidCallback? action, {
    String hint = '',
    String? id,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Semantics(
      identifier: id,
      child: TextFormField(
        key: ValueKey('$label$value${action == null}'),
        readOnly: true,
        enabled: action != null,
        initialValue: value,
        onTap: action,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: Icon(
            icon,
            color: action == null ? lavender : gold,
            size: 21,
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final h5 = H5Scope.of(context), c = h5.copy, zh = c.language == 'zh';
    final selected = _place != null && _place!.id != _province?.id;
    final stages = ['unspecified', 'considering', 'searching', 'offer'];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 365,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 330,
                  child: Image(
                    image: heroImage,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [night, Color(0x33130C24), Colors.transparent],
                      stops: [0, .6, 1],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [night, Colors.transparent],
                      stops: [0, .5],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zh ? '✦ 你的专属 AI 占星师' : '✦ หมอดู AI ส่วนตัวของคุณ',
                        style: const TextStyle(fontSize: 11, color: gold),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 285,
                        child: Text(
                          widget.topic == 'love'
                              ? (zh ? '运程解析' : 'วิเคราะห์ดวงชะตา')
                              : (zh
                                    ? '婚姻稳不稳？\n低谷还要熬多久？'
                                    : 'ชีวิตคู่มั่นคงไหม?\nเมื่อไหร่จะพ้นช่วงขาลง?'),
                          style: const TextStyle(
                            fontSize: 27,
                            height: 1.55,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        zh
                            ? '看清人生起伏，读懂下一程'
                            : 'เข้าใจแนวโน้มชีวิตและสิ่งที่ควรใส่ใจ',
                        style: const TextStyle(color: lavender, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(
                  zh ? '从出生时刻，读懂你的运程' : 'อ่านแนวโน้มชีวิตจากข้อมูลเกิดของคุณ',
                  subtitle: c.t('life', 'includesHint'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => showHistory(context, h5),
                    icon: const Icon(Icons.history, size: 17),
                    label: Text(c.t('life', 'history')),
                  ),
                ),
                _field(
                  '${c.t('ui', 'date')} · ${c.t('ui', 'ce')}',
                  _date,
                  Icons.calendar_month,
                  () => _datePicker(h5),
                  id: 'birth-date',
                ),
                _field(
                  c.t('ui', 'time'),
                  _time,
                  Icons.schedule,
                  _unknown ? null : _timePicker,
                  id: 'birth-time',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: Text(
                    c.t('ui', 'unknown'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _unknown,
                  onChanged: (v) => setState(() => _unknown = v!),
                ),
                if (_unknown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      c.t('ui', 'timeNote'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                _field(
                  c.t('ui', 'country'),
                  _country.isEmpty ? '' : c.t('ui', 'countryNames.$_country'),
                  Icons.expand_more,
                  () => _countryPicker(h5),
                  hint: c.t('ui', 'countryPlaceholder'),
                  id: 'birth-country',
                ),
                LayoutBuilder(
                  builder: (context, size) {
                    final fields = [
                      _field(
                        c.t('ui', 'province'),
                        _province?.label(c.language) ?? '',
                        Icons.expand_more,
                        _country.isEmpty ? null : () => _provincePicker(h5),
                        hint: c.t(
                          'ui',
                          _country == 'TH'
                              ? 'thaiProvincePlaceholder'
                              : 'provincePlaceholder',
                        ),
                        id: 'birth-province',
                      ),
                      _field(
                        c.t('ui', 'city'),
                        selected ? _place!.label(c.language) : '',
                        Icons.expand_more,
                        _province == null ? null : () => _cityPicker(h5),
                        hint: c.t(
                          'ui',
                          _country == 'TH'
                              ? 'thaiCityPlaceholder'
                              : 'cityPlaceholder',
                        ),
                        id: 'birth-city',
                      ),
                    ];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 10),
                        Expanded(child: fields[1]),
                      ],
                    );
                  },
                ),
                Text(
                  _place?.json['placeType'] == 'province'
                      ? c.t('ui', 'provinceNote')
                      : _place?.json['coordinateKind'] == 'administrative-area'
                      ? c.t('ui', 'areaNote')
                      : c.t('ui', 'placeHint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 22),
                Text(
                  c.t('career', 'questionPurpose'),
                  style: const TextStyle(color: gold, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (!_custom)
                  Panel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.question_answer_outlined,
                          color: gold,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            key: _questionKey,
                            height: 78,
                            child: Listener(
                              onPointerDown: (_) =>
                                  _interaction = DateTime.now(),
                              child: PageView.builder(
                                controller: _questionPages,
                                scrollDirection: Axis.vertical,
                                itemCount: 4,
                                onPageChanged: (i) => _questionIndex = i,
                                itemBuilder: (context, index) {
                                  final stage = stages[index];
                                  return InkWell(
                                    onTap: () => setState(
                                      () => _question = _question == stage
                                          ? null
                                          : stage,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 7,
                                        horizontal: 5,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              c.t(
                                                'career',
                                                'situations.$stage.question',
                                              ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _question == stage
                                                    ? gold
                                                    : cream,
                                              ),
                                            ),
                                          ),
                                          if (_question == stage)
                                            const Icon(
                                              Icons.check_circle,
                                              color: gold,
                                              size: 18,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: c.t('career', 'browseQuestions'),
                          onPressed: () {
                            _interaction = DateTime.now();
                            _questionPages.jumpToPage((_questionIndex + 1) % 4);
                          },
                          icon: const Icon(
                            Icons.unfold_more,
                            color: gold,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_custom)
                  TextField(
                    controller: _questionText,
                    maxLength: 120,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(
                        RegExp(r'[\x00-\x1f\x7f]'),
                        replacementString: ' ',
                      ),
                      TextInputFormatter.withFunction((old, next) {
                        if (next.text.runes.length <= 120) return next;
                        final text = String.fromCharCodes(
                          next.text.runes.take(120),
                        );
                        return TextEditingValue(
                          text: text,
                          selection: TextSelection.collapsed(
                            offset: text.length,
                          ),
                        );
                      }),
                    ],
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: c.t('career', 'customQuestion'),
                    ),
                    onChanged: (value) {
                      final clean = value.replaceAll(
                        RegExp(r'[\x00-\x1f\x7f]'),
                        ' ',
                      );
                      if (clean != value) _questionText.text = clean;
                    },
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _custom = !_custom;
                      _question = null;
                    }),
                    child: Text(
                      c.t(
                        'career',
                        _custom ? 'browseQuestions' : 'writeQuestion',
                      ),
                    ),
                  ),
                ),
                errorMessage(_error),
                FilledButton.icon(
                  onPressed: h5.languageLoading || _confirming
                      ? null
                      : () => _generate(h5),
                  icon: const Icon(Icons.menu_book_outlined, size: 20),
                  label: Text(c.t('life', 'generate')),
                ),
                const SizedBox(height: 32),
                SectionTitle(
                  c.t('life', 'includes'),
                  subtitle: c.t('life', 'includesHint'),
                ),
                for (var i = 0; i < c.topics.length; i += i == 0 ? 1 : 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: i == 0
                        ? _topicCard(c, c.topics[0], DateTime.now().year)
                        : IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _topicCard(
                                    c,
                                    c.topics[i],
                                    DateTime.now().year,
                                  ),
                                ),
                                if (i + 1 < c.topics.length) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _topicCard(
                                      c,
                                      c.topics[i + 1],
                                      DateTime.now().year,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                const SizedBox(height: 8),
                Text(
                  c.t('ui', 'formHint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () =>
                          context.go('/privacy.html?lang=${h5.language}'),
                      child: Text(c.t('experience', 'privacy')),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.go('/support.html?lang=${h5.language}'),
                      child: Text(c.t('experience', 'support')),
                    ),
                  ],
                ),
                Text(
                  zh
                      ? '解读由 AI 生成，仅供娱乐与自我探索'
                      : 'คำอ่านสร้างด้วย AI เพื่อความบันเทิงและสำรวจตัวเอง',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topicCard(Copy c, Json topic, int year) {
    final key = text(topic['key']);
    final icons = {
      'annual': Icons.calendar_month_outlined,
      'overall': Icons.explore_outlined,
      'pattern': Icons.auto_awesome_outlined,
      'marriage': Icons.favorite_outline,
      'wealth': Icons.savings_outlined,
      'risk': Icons.shield_outlined,
      'romance': Icons.volunteer_activism_outlined,
    };
    return Panel(
      padding: const EdgeInsets.all(16),
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icons[key], color: gold, size: 25),
              ),
              const Spacer(),
              const Icon(Icons.lock_outline, color: gold, size: 14),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            c.topicTitle(topic, year),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            text(object(topic[c.language])['subtitle']),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
