import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'generation_video.dart' show GenerationPoster;

/// Own the web video element so JY's CSS mask applies to its video surface.
class GenerationVideo extends StatefulWidget {
  const GenerationVideo({
    required this.active,
    required this.reduced,
    required this.onFinished,
    this.finishing = false,
    super.key,
  });
  final bool active, reduced, finishing;
  final VoidCallback onFinished;
  @override
  State<GenerationVideo> createState() => _GenerationVideoState();
}

class _GenerationVideoState extends State<GenerationVideo>
    with WidgetsBindingObserver {
  web.HTMLVideoElement? _video;
  final _events = <StreamSubscription<web.Event>>[];
  Timer? _watchdog, _fallback;
  bool _finished = false, _failed = false;
  double _lastTime = 0;
  DateTime _advanced = DateTime.now();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _created(Object element) {
    final video = element as web.HTMLVideoElement;
    _video = video;
    video
      ..src = Uri.base.resolve('media/report-loading-web.mp4').toString()
      ..poster = Uri.base
          .resolve('assets/assets/images/report-loading-poster.webp')
          .toString()
      ..muted = true
      ..playsInline = true
      ..autoplay = widget.active
      ..loop = !widget.finishing
      ..preload = 'auto';
    video.setAttribute('aria-hidden', 'true');
    video.setAttribute('webkit-playsinline', 'true');
    video.setAttribute('x5-playsinline', 'true');
    final style = video.style;
    style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'contain'
      ..pointerEvents = 'none'
      ..transform = 'scale(1.06)'
      ..background = 'transparent'
      ..opacity = '0'
      ..visibility = 'hidden'
      ..transition = 'opacity .7s ease-out';
    const mask =
        'linear-gradient(to right,transparent 3%,#0005 7%,#000c 12%,#000 18% 82%,#000c 88%,#0005 93%,transparent 97%),linear-gradient(to bottom,transparent 3%,#0004 9%,#000c 17%,#000 27% 80%,#000b 90%,#0004 94%,transparent 97%)';
    style.setProperty('mask-image', mask);
    style.setProperty('mask-composite', 'intersect');
    style.setProperty('-webkit-mask-image', mask);
    style.setProperty('-webkit-mask-composite', 'source-in');
    _events.add(
      video.onEnded.listen((_) {
        if (widget.finishing) {
          _finish();
        } else if (widget.active) {
          unawaited(_play());
        }
      }),
    );
    _events.add(
      video.onError.listen((_) {
        _playbackFailed();
      }),
    );
    _events.add(
      web.document.onVisibilityChange.listen((_) {
        if (web.document.visibilityState == 'hidden') {
          video.pause();
        } else if (widget.active) {
          _advanced = DateTime.now();
          unawaited(_play());
        }
      }),
    );
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(covariant GenerationVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    _video?.loop = !widget.finishing;
    if (widget.finishing && !oldWidget.finishing && _failed) _finishSoon();
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _start();
      } else {
        _video?.pause();
        _video?.style.visibility = 'hidden';
        _watchdog?.cancel();
      }
    }
  }

  void _start() {
    final video = _video;
    if (video == null || !mounted || _finished) return;
    video.style.visibility = 'visible';
    video.style.opacity = '1';
    _advanced = DateTime.now();
    if (_failed) {
      if (widget.finishing) _finishSoon();
      return;
    }
    unawaited(_play());
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.active) return;
      if (web.document.visibilityState == 'hidden') {
        _advanced = DateTime.now();
        return;
      }
      final position = video.currentTime.toDouble();
      if ((position - _lastTime).abs() > .01) {
        _lastTime = position;
        _advanced = DateTime.now();
      } else if (DateTime.now().difference(_advanced) >=
          const Duration(seconds: 8)) {
        _playbackFailed();
      }
    });
  }

  Future<void> _play() async {
    try {
      await _video?.play().toDart;
    } catch (_) {
      if (mounted && widget.active) _playbackFailed();
    }
  }

  void _playbackFailed() {
    if (!mounted) return;
    _watchdog?.cancel();
    _video?.pause();
    _video?.style.visibility = 'hidden';
    if (!_failed) setState(() => _failed = true);
    if (widget.finishing) _finishSoon();
  }

  void _finishSoon() {
    _fallback ??= Timer(const Duration(milliseconds: 550), _finish);
  }

  void _finish() {
    if (!mounted || !widget.active || !widget.finishing || _finished) return;
    _finished = true;
    _watchdog?.cancel();
    widget.onFinished();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) {
      _advanced = DateTime.now();
      unawaited(_play());
    } else {
      _video?.pause();
    }
  }

  @override
  void dispose() {
    _finished = true;
    WidgetsBinding.instance.removeObserver(this);
    _watchdog?.cancel();
    _fallback?.cancel();
    for (final event in _events) {
      unawaited(event.cancel());
    }
    _video?.pause();
    _video?.removeAttribute('src');
    _video?.load();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.reduced || _failed
      ? Opacity(opacity: widget.active ? 1 : 0, child: const GenerationPoster())
      : HtmlElementView.fromTagName(
          tagName: 'video',
          onElementCreated: _created,
        );
}
