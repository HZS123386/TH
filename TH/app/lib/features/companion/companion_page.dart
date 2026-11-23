import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../core/storage/session_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';
import '../account/privacy_page.dart';
import '../actions/action_page.dart';
import '../home/reading_guide.dart';
import '../reports/content_report_sheet.dart';
import 'companion_view_model.dart';
import 'guardian.dart';

part 'guide_chat.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({
    required Guardian this.guardian,
    this.reading,
    super.key,
  }) : guide = null,
       voice = false,
       sample = false;
  const CompanionPage.guide({
    required ReadingGuide this.guide,
    this.voice = false,
    this.sample = false,
    super.key,
  }) : guardian = null,
       reading = null;
  final Guardian? guardian;
  final ReadingGuide? guide;
  final ReadingHandoff? reading;
  final bool voice, sample;
  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  CompanionViewModel? _model;
  late ReadingHandoff? _reading = widget.reading;
  bool _requestingConsent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model != null || widget.guide != null) return;
    _model = DependencyScope.of(context).companion;
    if (_reading != null) {
      _input.text =
          _reading!.question ?? AppLocalizations.of(context).readingQuestion;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _model!.select(widget.guardian!);
      await _model!.load();
      _scrollToEnd(animate: false);
    });
  }

  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        if (!animate || FateMotion.reduced(context)) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        } else {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: FateMotion.change,
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty || _requestingConsent) return;
    _requestingConsent = true;
    final permitted = await requestCompanionConsent(context);
    _requestingConsent = false;
    if (!permitted || !mounted) return;
    final reply = _model!.send(widget.guardian!, text, reading: _reading);
    _scrollToEnd();
    if (await reply && mounted) {
      _input.clear();
      setState(() => _reading = null);
    }
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.guide case final guide?) {
      return _GuideChat(
        initialGuide: guide,
        voice: widget.voice,
        sample: widget.sample,
      );
    }
    final d = DependencyScope.of(context), s = AppLocalizations.of(context);
    final guardian = widget.guardian!;
    return ListenableBuilder(
      listenable: Listenable.merge([d.companion, d.session]),
      builder: (context, _) {
        final model = d.companion;
        final messages = model.conversation(guardian);
        final needsProfile =
            d.session.profile == null || model.error == 'profile_required';
        final reading =
            _reading?.owner != null && _reading!.owner != d.session.owner
            ? null
            : _reading;
        final unavailable =
            d.session.capabilities.companionProvider == null ||
            model.error == 'production_disabled';
        final enabled =
            !model.sending && !model.loading && !needsProfile && !unavailable;
        final listening = model.sending && model.sendingGuardian == guardian;
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
                child: Row(
                  children: [
                    BackButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/fortune'),
                    ),
                    GuardianAvatar(guardian, size: 48, hero: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guardian.title(s),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            guardian.note(s),
                            style: TextStyle(
                              fontSize: 10,
                              color: guardian.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: s.divinationNav,
                      onPressed: () => context.push('/divination'),
                      icon: const Icon(Icons.auto_awesome_outlined, size: 21),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  s.aiCompanionNotice,
                  style: const TextStyle(color: mutedColor, fontSize: 10),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (messages.isEmpty) ...[
                      FateEntrance(
                        child: Center(
                          child: Container(
                            width: 280,
                            height: 260,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  guardian.color.withValues(alpha: .15),
                                  canvasColor,
                                ],
                                radius: .5,
                              ),
                            ),
                            child: Container(
                              width: 160,
                              height: 210,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(100),
                                  bottom: Radius.circular(24),
                                ),
                                border: Border.all(
                                  color: guardian.color.withValues(alpha: .35),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(100),
                                  bottom: Radius.circular(20),
                                ),
                                child: Image.asset(
                                  guardian.image,
                                  fit: BoxFit.cover,
                                  alignment: const Alignment(0, -.6),
                                  cacheWidth: 480,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.listenIntro,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, height: 1.8),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (model.loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    for (final row in messages)
                      if (row['role'] == 'assistant')
                        FateEntrance(
                          key: ValueKey('reply-${row['id']}'),
                          child: _MessageBubble(
                            text: row['content'] as String? ?? '',
                            user: false,
                            accent: guardian.color,
                            onReport: () => showContentReport(
                              context,
                              kind: 'chat',
                              id: row['id'] as String,
                            ),
                          ),
                        )
                      else
                        _MessageBubble(
                          key: ValueKey('message-${row['id']}'),
                          text: row['content'] as String? ?? '',
                          user: row['role'] == 'user',
                          accent: guardian.color,
                        ),
                    if (listening) ...[
                      FateEntrance(
                        key: const ValueKey('pending-message'),
                        child: _MessageBubble(
                          text: model.pendingMessage ?? '',
                          user: true,
                          accent: guardian.color,
                        ),
                      ),
                      _ListeningIndicator(
                        color: guardian.color,
                        label: s.assistantListening,
                      ),
                    ],
                    if (reading != null) ...[
                      const SizedBox(height: 14),
                      FateCard(
                        padding: const EdgeInsets.all(16),
                        gold: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.selectedReading} · ${reading.title}',
                              style: const TextStyle(
                                color: goldColor,
                                fontSize: 12,
                              ),
                            ),
                            if (reading.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                reading.text,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (model.error != null &&
                        !needsProfile &&
                        !unavailable) ...[
                      const SizedBox(height: 16),
                      FateEntrance(
                        child: Column(
                          children: [
                            Text(
                              s.chatFailure,
                              style: const TextStyle(
                                color: Color(0xFFF1B5B5),
                                fontSize: 12,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: model.loading || model.sending
                                  ? null
                                  : () => model.load(force: true),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(s.chatTryAgain),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (needsProfile || unavailable)
                      FateCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Text(
                              needsProfile
                                  ? s.chatProfileNeeded
                                  : s.chatUnavailable,
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            if (needsProfile)
                              TextButton(
                                onPressed: () => context.push('/birth'),
                                child: Text(s.editBirth),
                              ),
                          ],
                        ),
                      ),
                    if (messages.isEmpty && !model.sending)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ActionChip(
                            backgroundColor: panelColor,
                            side: const BorderSide(color: lineColor),
                            shape: const StadiumBorder(),
                            label: Text(
                              guardian.prompt(s),
                              maxLines: 2,
                              softWrap: true,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () => _input.text = guardian.prompt(s),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        enabled: !model.sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          hintText: s.messageHint,
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (_) {
                          if (enabled) _send();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      tooltip: s.sendMessage,
                      onPressed: enabled ? _send : null,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: AnimatedSwitcher(
                        duration: FateMotion.duration(
                          context,
                          FateMotion.settle,
                        ),
                        child: listening
                            ? const SizedBox(
                                key: ValueKey('sending'),
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_upward_rounded,
                                key: ValueKey('send'),
                              ),
                      ),
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

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.user,
    required this.accent,
    this.onReport,
    this.footer,
    super.key,
  });
  final String text;
  final bool user;
  final Color accent;
  final VoidCallback? onReport;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Align(
    alignment: user ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: EdgeInsets.only(
        bottom: 16,
        left: user ? 32 : 0,
        right: user ? 0 : 24,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
      decoration: BoxDecoration(
        color: user ? accent.withValues(alpha: .14) : panelColor,
        borderRadius: BorderRadius.circular(20).copyWith(
          bottomRight: user ? const Radius.circular(5) : null,
          bottomLeft: user ? null : const Radius.circular(5),
        ),
        border: Border.all(
          color: user ? accent.withValues(alpha: .25) : lineColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            text,
            style: const TextStyle(fontSize: 14, height: 1.9),
          ),
          ?footer,
          if (onReport != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.flag_outlined, size: 15),
                label: Text(
                  AppLocalizations.of(context).contentReport,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ListeningIndicator extends StatefulWidget {
  const _ListeningIndicator({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  State<_ListeningIndicator> createState() => _ListeningIndicatorState();
}

class _ListeningIndicatorState extends State<_ListeningIndicator>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (FateMotion.reduced(context)) {
      _pulse.stop();
      _pulse.value = .5;
    } else {
      _pulse.repeat();
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: widget.label,
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AnimatedBuilder(
        animation: _pulse,
        child: Flexible(
          child: Text(
            widget.label,
            style: TextStyle(fontSize: 12, color: widget.color),
          ),
        ),
        builder: (context, label) => Row(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Opacity(
                  opacity: FateMotion.reduced(context)
                      ? .6
                      : .4 +
                            .6 *
                                (math.sin(
                                      (_pulse.value - i * .18) * math.pi * 2,
                                    ) +
                                    1) /
                                2,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 7),
            label!,
          ],
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }
}
