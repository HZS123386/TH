import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/asset_tile.dart';
import '../../ui/theme.dart';

const homeHeroImage = AssetImage('assets/images/temple-sanctuary.png');
const objectsArtwork = 'assets/images/objects.png';

enum LiveRoom {
  temple,
  objects;

  String title(AppLocalizations s) =>
      this == temple ? s.templeRoom : s.objectsRoom;
  String teaser(AppLocalizations s) =>
      this == temple ? s.templeTeaser : s.objectsRoom;
  String note(AppLocalizations s) =>
      this == temple ? s.templeTeaserNote : s.objectsTeaserNote;
}

class LiveTeasers extends StatelessWidget {
  const LiveTeasers({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return FateCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.circle, color: Color(0xFFE7AAAE), size: 7),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  s.onAirNow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                s.demo,
                style: const TextStyle(fontSize: 10, color: mutedColor),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/live'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(42, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: Row(
                  children: [
                    Text(s.allItems, style: const TextStyle(fontSize: 11)),
                    const Icon(Icons.chevron_right, size: 15),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              for (final room in LiveRoom.values) ...[
                if (room != LiveRoom.values.first) const SizedBox(width: 8),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.72,
                    child: Material(
                      color: canvasColor,
                      borderRadius: BorderRadius.circular(11),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.go('/live?room=${room.name}'),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _RoomArt(room),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x390F0B18),
                                    Color(0xCC160E20),
                                  ],
                                ),
                              ),
                            ),
                            const Positioned(
                              right: 8,
                              top: 8,
                              child: Icon(
                                Icons.play_circle_outline,
                                color: inkColor,
                                size: 20,
                              ),
                            ),
                            Positioned(
                              left: 9,
                              right: 8,
                              bottom: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.teaser(s),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    room.note(s),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFE0D6DE),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RoomArt extends StatelessWidget {
  const _RoomArt(this.room, {this.phase = 0, super.key});
  final LiveRoom room;
  final int phase;

  @override
  Widget build(BuildContext context) => room == LiveRoom.temple
      ? Image(
          image: homeHeroImage,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment(phase.isEven ? 1 : .65, 0),
          excludeFromSemantics: true,
        )
      : AssetTile(
          objectsArtwork,
          column: 1,
          row: phase.isEven ? 0 : 1,
          rows: 2,
        );
}

class LivePage extends StatefulWidget {
  const LivePage({required this.room, super.key});
  final LiveRoom room;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  bool _playing = true, _details = false;
  int _seconds = 0;
  Timer? _timer;
  final _input = TextEditingController();
  final _messages = <String>[];

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void didUpdateWidget(covariant LivePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.room == oldWidget.room) return;
    _seconds = 0;
    _details = false;
    _messages.clear();
    _input.clear();
  }

  void _play() {
    _timer?.cancel();
    if (_playing) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          setState(() => _seconds = (_seconds + 1) % 36);
        }
      });
    }
  }

  void _toggle() {
    setState(() => _playing = !_playing);
    _play();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (_messages.length >= 12) _messages.removeAt(0);
      _messages.add(text);
    });
    _input.clear();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _pickRoom(BuildContext context) async {
    final s = AppLocalizations.of(context);
    final room = await showModalBottomSheet<LiveRoom>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      sheetAnimationStyle: FateMotion.dialog(context),
      constraints: const BoxConstraints(maxWidth: 430),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final room in LiveRoom.values)
              ListTile(
                leading: Icon(
                  room == LiveRoom.temple
                      ? Icons.temple_buddhist_outlined
                      : Icons.shopping_bag_outlined,
                ),
                title: Text(room.title(s)),
                subtitle: Text(s.liveDemoNotice),
                trailing: room == widget.room
                    ? const Icon(Icons.check, color: goldColor)
                    : null,
                onTap: () => Navigator.pop(sheet, room),
              ),
          ],
        ),
      ),
    );
    if (mounted && room != null) this.context.go('/live?room=${room.name}');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final temple = widget.room == LiveRoom.temple;
    return ListView(
      key: const PageStorageKey('live-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Row(
          children: [
            IconButton.outlined(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => context.go('/fortune'),
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.room.title(s),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    temple ? s.templeRoomNote : s.sampleCatalog,
                    style: const TextStyle(color: mutedColor, fontSize: 11),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _pickRoom(context),
              child: Text(s.switchRoom, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FateEntrance(child: _poster(context)),
        const SizedBox(height: 16),
        Text(
          temple ? s.templeRoomHeading : s.storeTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(widget.room.note(s), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        FateCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 55,
                  height: 59,
                  child: _RoomArt(widget.room),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(temple ? s.templeService : s.objectCandle),
                    Text(
                      temple ? '฿1,280 · ${s.samplePrice}' : s.sampleCatalog,
                      style: const TextStyle(color: goldColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                ),
                onPressed: temple
                    ? () => _showBooking(context)
                    : () => context.go('/shop'),
                child: Text(
                  temple ? s.bookingInfo : s.objectsTab,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(s.roomChat),
              selected: !_details,
              onSelected: (_) => setState(() => _details = false),
            ),
            ChoiceChip(
              label: Text(temple ? s.ceremonyInfo : s.roomObjectsInfo),
              selected: _details,
              onSelected: (_) => setState(() => _details = true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: FateMotion.duration(context, FateMotion.change),
          child: _details
              ? Column(
                  key: const ValueKey('details'),
                  children: [
                    for (final (index, description)
                        in (temple
                                ? [
                                    s.templeSegmentOne,
                                    s.templeSegmentTwo,
                                    s.templeSegmentThree,
                                  ]
                                : [
                                    s.objectJournalNote,
                                    s.objectCandleNote,
                                    s.objectDiffuserNote,
                                  ])
                            .indexed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        title: Text(description),
                      ),
                  ],
                )
              : Column(
                  key: const ValueKey('interaction'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.roomWelcomeDemo,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    for (final message in _messages)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          message,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _input,
                      maxLength: 140,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: s.roomMessageHint,
                        counterText: '',
                        suffixIcon: IconButton(
                          onPressed: _send,
                          icon: const Icon(Icons.send_outlined),
                          tooltip: s.sendMessage,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _poster(BuildContext context) {
    final s = AppLocalizations.of(context);
    return FateCard(
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 1.11,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: FateMotion.duration(
                context,
                const Duration(milliseconds: 650),
              ),
              child: _RoomArt(
                widget.room,
                key: ValueKey((widget.room, _seconds ~/ 6)),
                phase: _seconds ~/ 6,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .42, 1],
                  colors: [
                    Color(0x3712091D),
                    Color(0x1712091D),
                    Color(0xF4181120),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 14,
              left: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '●  ${s.onAirNow} · ${s.demo}',
                    style: const TextStyle(color: inkColor, fontSize: 11),
                  ),
                  Text(
                    '00:${_seconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 18,
              bottom: 53,
              right: 18,
              child: Text(
                widget.room == LiveRoom.temple
                    ? s.templePosterTitle
                    : s.objectsPosterTitle,
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.43,
                  color: inkColor,
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 4,
              child: Row(
                children: [
                  IconButton(
                    tooltip: _playing ? s.livestreamPause : s.livestreamPlay,
                    onPressed: _toggle,
                    icon: Icon(
                      _playing ? Icons.pause : Icons.play_arrow,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      s.liveDemoNotice,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: mutedColor),
                    ),
                  ),
                  IconButton(
                    tooltip: s.fullScreenPreview,
                    icon: const Icon(Icons.fullscreen, size: 22),
                    onPressed: () => showDialog<void>(
                      context: context,
                      animationStyle: FateMotion.dialog(context),
                      builder: (_) => Dialog(
                        clipBehavior: Clip.antiAlias,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _RoomArt(widget.room, phase: _seconds ~/ 6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBooking(BuildContext context) {
    final s = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      animationStyle: FateMotion.dialog(context),
      builder: (sheet) => AlertDialog(
        title: Text(s.templeService),
        content: Text('฿1,280 · ${s.samplePrice}\n\n${s.bookingDemoNotice}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(sheet),
            child: Text(s.close),
          ),
        ],
      ),
    );
  }
}
