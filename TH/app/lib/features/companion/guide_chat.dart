part of 'companion_page.dart';

class _GuideChat extends StatefulWidget {
  const _GuideChat({
    required this.initialGuide,
    required this.voice,
    required this.sample,
  });

  final ReadingGuide initialGuide;
  final bool voice, sample;

  @override
  State<_GuideChat> createState() => _GuideChatState();
}

class _GuideChatState extends State<_GuideChat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late var _active = widget.initialGuide;
  late var _voice = widget.voice;
  bool _saving = false;
  String? _owner;

  List<Map<String, dynamic>> _history(AppDependencies d, String owner) {
    final rows = d.session.drafts.read(
      owner,
      LocalDraftStore.guideConversations,
    )?[_active.name];
    if (rows is! List) return [];
    return rows
        .whereType<Map<String, dynamic>>()
        .where((row) => row['text'] is String)
        .toList();
  }

  void _toLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (FateMotion.reduced(context)) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: FateMotion.change,
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send(AppDependencies d, AppLocalizations s) async {
    final text = _input.text.trim();
    if (_saving || text.isEmpty) return;
    final owner = d.session.owner, guide = _active;
    final draft = d.session.drafts.read(
      owner,
      LocalDraftStore.guideConversations,
    );
    final history = _history(d, owner);
    final question = text.characters.take(90).toString();
    final reply = switch (text) {
      _ when text == s.guidePromptWork || text == s.readingSampleQuestion =>
        s.guideWorkReply,
      _ when text == s.guidePromptLove || text == s.readingSampleLove =>
        s.guideLoveReply,
      _ => s.guideReflectReply(question),
    };
    final recent = [
      ...history.skip(math.max(0, history.length - 38)),
      {'text': text, 'user': true},
      {'text': reply, 'user': false},
    ];
    setState(() => _saving = true);
    try {
      await d.session.drafts.write(owner, LocalDraftStore.guideConversations, {
        ...?draft,
        'last': guide.name,
        guide.name: recent,
      });
      if (mounted && owner == d.session.owner) {
        _input.clear();
        _toLatest();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.error)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void didUpdateWidget(covariant _GuideChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialGuide != widget.initialGuide ||
        oldWidget.voice != widget.voice) {
      _active = widget.initialGuide;
      _voice = widget.voice;
      _input.clear();
      _toLatest();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), d = DependencyScope.of(context);
    return ListenableBuilder(
      listenable: d.session,
      builder: (context, _) {
        final owner = d.session.owner;
        if (_owner != owner) {
          if (_owner != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && d.session.owner == owner) _input.clear();
            });
          }
          _owner = owner;
          _toLatest();
        }
        final rows = _history(d, owner);
        final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!keyboard) ...[
                Row(
                  children: [
                    for (final guide in ReadingGuide.values) ...[
                      if (guide.index > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _GuideChip(
                          guide: guide,
                          selected: _active == guide,
                          onTap: _saving || _active == guide
                              ? null
                              : () {
                                  setState(() {
                                    _active = guide;
                                    _input.clear();
                                  });
                                  _toLatest();
                                },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_active.name.toUpperCase()} · ${_active.method(s)}',
                            style: const TextStyle(
                              color: goldColor,
                              fontSize: 10,
                              letterSpacing: .6,
                            ),
                          ),
                          Text(
                            s.guideChatHeading(_active.displayName(s)),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: () => _active.start(context),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 15),
                      label: Text(
                        s.startReading,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.chat_outlined, size: 17),
                      label: Text(s.textChat),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.headphones, size: 17),
                      label: Text(s.voiceChat),
                    ),
                  ],
                  selected: {_voice},
                  onSelectionChanged: (selected) {
                    setState(() => _voice = selected.first);
                    if (!_voice) _toLatest();
                  },
                ),
                const SizedBox(height: 7),
                if (!_voice)
                  FateCard(
                    gold: true,
                    radius: 12,
                    padding: const EdgeInsets.fromLTRB(11, 8, 10, 8),
                    onTap: () {
                      _input.text = _active.sampleQuestion(s);
                      if (widget.sample) _send(d, s);
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.article_outlined,
                          color: goldColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.continueSample,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: goldColor,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                _active.sampleQuestion(s),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 17,
                          color: mutedColor,
                        ),
                      ],
                    ),
                  ),
              ],
              if (_voice)
                Expanded(
                  child: Center(
                    child: FateEntrance(
                      child: FateCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FateEmblem(Icons.headphones, size: 58),
                            const SizedBox(height: 12),
                            Text(
                              s.voicePreviewNotice,
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() => _voice = false);
                                _toLatest();
                              },
                              child: Text(s.textChat),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(top: 12, bottom: 2),
                    children: [
                      if (rows.isEmpty)
                        _MessageBubble(
                          text: s.guideGreeting,
                          user: false,
                          accent: _active.color,
                        ),
                      for (final (index, row) in rows.indexed)
                        FateEntrance(
                          key: ValueKey((owner, _active, index, row['text'])),
                          child: _MessageBubble(
                            text: row['text'] as String,
                            user: row['user'] == true,
                            accent: _active.color,
                            footer:
                                row['user'] == true || index != rows.length - 1
                                ? null
                                : Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => showActionEditor(
                                        context,
                                        initialTitle: s.careAction,
                                      ),
                                      icon: const Icon(
                                        Icons.eco_outlined,
                                        size: 14,
                                      ),
                                      label: Text(
                                        s.recordAction,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!keyboard)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final prompt in [
                          s.guidePromptWork,
                          s.guidePromptLove,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              onPressed: _saving
                                  ? null
                                  : () => _input.text = prompt,
                              label: Text(
                                prompt,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _input,
                  enabled: !_saving,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(d, s),
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: s.messageHint,
                    counterText: '',
                    suffixIcon: IconButton.filled(
                      tooltip: s.sendMessage,
                      onPressed: _saving ? null : () => _send(d, s),
                      icon: const Icon(Icons.send_outlined, size: 17),
                    ),
                  ),
                ),
                if (!keyboard)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      s.guideChatDemo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9, color: mutedColor),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }
}

class _GuideChip extends StatelessWidget {
  const _GuideChip({required this.guide, required this.selected, this.onTap});
  final ReadingGuide guide;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return FateCard(
      onTap: onTap,
      gold: selected,
      radius: 12,
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(width: 28, height: 34, child: GuidePortrait(guide)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guide.displayName(s),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? goldColor : inkColor,
                  ),
                ),
                Text(
                  guide.method(s),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8, color: mutedColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
