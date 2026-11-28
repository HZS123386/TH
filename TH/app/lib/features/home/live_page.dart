import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/asset_tile.dart';
import '../../ui/theme.dart';
import '../shop/shop_page.dart';

const homeHeroImage = AssetImage(
  'assets/images/action-offering-sanctuary.webp',
);

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

class _LiveLobby extends StatefulWidget {
  const _LiveLobby();

  @override
  State<_LiveLobby> createState() => _LiveLobbyState();
}

class _LiveLobbyState extends State<_LiveLobby> {
  bool _onlyBooked = false;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final dependencies = DependencyScope.of(context);
    return ListView(
      key: const PageStorageKey('live-lobby-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(s.liveTab, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        FateCard(
          padding: EdgeInsets.zero,
          radius: 22,
          child: Stack(
            children: [
              const Positioned.fill(child: _RoomArt(LiveRoom.temple)),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, .37, 1],
                      colors: [
                        Color(0x40140B25),
                        Color(0x32140B25),
                        Color(0xFF160E22),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6D2838),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          s.livePreview,
                          style: const TextStyle(fontSize: 11, color: inkColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 46),
                    Text(
                      LiveRoom.temple.title(s),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      LiveRoom.temple.note(s),
                      style: const TextStyle(fontSize: 12, color: inkColor),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => context.go('/live?room=temple'),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(s.liveWatch),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FateCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.play_circle_outline, color: goldColor),
            title: Text(LiveRoom.objects.title(s)),
            subtitle: Text(LiveRoom.objects.note(s)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/live?room=objects'),
          ),
        ),
        const SizedBox(height: 20),
        ValueListenableBuilder(
          valueListenable: dependencies.demoLiveBookings,
          builder: (context, bookings, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    s.liveUpcoming,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 19),
                  ),
                  FilterChip(
                    label: Text('${s.liveMyReservations} (${bookings.length})'),
                    selected: _onlyBooked,
                    onSelected: (selected) {
                      FateMotion.selectionFeedback();
                      setState(() => _onlyBooked = selected);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_onlyBooked && bookings.isEmpty)
                FateCard(child: Text(s.liveNoReservations)),
              for (final room in LiveRoom.values)
                if (!_onlyBooked || bookings.contains(room.name))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _scheduleCard(
                      context,
                      room,
                      dependencies,
                      bookings.contains(room.name),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scheduleCard(
    BuildContext context,
    LiveRoom room,
    AppDependencies dependencies,
    bool booked,
  ) {
    final s = AppLocalizations.of(context);
    final today = dependencies.demoLiveDate;
    final starts = DateTime(
      today.year,
      today.month,
      today.day + room.index + 1,
      20,
    );
    final material = MaterialLocalizations.of(context);
    final time =
        '${material.formatMediumDate(starts)} · ${material.formatTimeOfDay(TimeOfDay.fromDateTime(starts), alwaysUse24HourFormat: true)}';
    final title = room == LiveRoom.temple
        ? s.liveTempleUpcoming
        : s.liveObjectsUpcoming;
    final button = OutlinedButton.icon(
      style: booked
          ? OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB9D6AD),
              backgroundColor: const Color(0x263B7447),
              side: const BorderSide(color: Color(0x7A83A477)),
            )
          : null,
      onPressed: () =>
          _confirmBooking(context, dependencies, room, title, time, booked),
      icon: Icon(
        booked ? Icons.check_circle_outline : Icons.notifications_none,
        size: 17,
      ),
      label: Semantics(
        liveRegion: true,
        child: Text(booked ? s.liveReserved : s.liveReserve),
      ),
    );
    return FateCard(
      padding: const EdgeInsets.all(12),
      radius: 16,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox.square(dimension: 50, child: _RoomArt(room)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(time, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                button,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBooking(
    BuildContext context,
    AppDependencies dependencies,
    LiveRoom room,
    String title,
    String time,
    bool booked,
  ) async {
    final s = AppLocalizations.of(context);
    final action = booked ? s.liveCancelReservation : s.liveReserve;
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: FateMotion.dialog(context),
      builder: (dialog) => AlertDialog(
        title: Text(action),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(time, style: Theme.of(dialog).textTheme.bodySmall),
            const SizedBox(height: 10),
            Text(
              s.liveReservationDemo,
              style: Theme.of(dialog).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(s.close),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    FateMotion.selectionFeedback();
    final bookings = {...dependencies.demoLiveBookings.value};
    if (booked) {
      bookings.remove(room.name);
    } else {
      bookings.add(room.name);
    }
    dependencies.demoLiveBookings.value = Set.unmodifiable(bookings);
  }
}

class LivePage extends StatefulWidget {
  const LivePage({this.room, super.key});
  final LiveRoom? room;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  bool _playing = true, _details = false;
  final _elapsed = ValueNotifier<int>(0);
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
    _elapsed.value = 0;
    _playing = true;
    _details = false;
    _messages.clear();
    _input.clear();
    _play();
  }

  void _play() {
    _timer?.cancel();
    if (_playing && widget.room != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsed.value = (_elapsed.value + 1) % 36;
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
    _elapsed.dispose();
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
    final room = widget.room;
    if (room == null) return const _LiveLobby();
    final temple = room == LiveRoom.temple;
    return ListView(
      key: PageStorageKey(room),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Row(
          children: [
            IconButton.outlined(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => context.go('/live'),
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title(s),
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
        FateEntrance(child: _poster(context, room)),
        const SizedBox(height: 16),
        Text(
          room == LiveRoom.temple ? s.templeRoomHeading : s.objectsRoom,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(room.note(s), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        Text(s.roomObjectsInfo, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        if (temple)
          const LiveShopProduct.journal()
        else
          const LiveShopProduct.candle(),
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
              label: Text(temple ? s.ceremonyInfo : s.liveAboutShow),
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

  Widget _poster(BuildContext context, LiveRoom room) {
    final s = AppLocalizations.of(context);
    return FateCard(
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 1.38,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _previewArt(room),
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
                  ValueListenableBuilder(
                    valueListenable: _elapsed,
                    builder: (context, seconds, _) => Text(
                      '00:${seconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                        fontSize: 12,
                      ),
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
                room == LiveRoom.temple
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
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: AspectRatio(
                            aspectRatio: 1.38,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _previewArt(room),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: IconButton.filledTonal(
                                    onPressed: () => Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).pop(),
                                    tooltip: s.close,
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  Widget _previewArt(LiveRoom room) => ValueListenableBuilder(
    valueListenable: _elapsed,
    builder: (context, seconds, _) => AnimatedSwitcher(
      duration: FateMotion.duration(context, const Duration(milliseconds: 650)),
      child: _RoomArt(room, key: ValueKey(seconds ~/ 6), phase: seconds ~/ 6),
    ),
  );
}
