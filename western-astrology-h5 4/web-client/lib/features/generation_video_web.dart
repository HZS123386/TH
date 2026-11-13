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
  Timer? _watchdog, _fallback, _playRetry, _imageRetry;
  bool _finished = false,
      _failed = false,
      _playPending = false,
      _imageFailed = false;
  int _playAttempts = 0, _imageAttempts = 0;
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
    _styleSurface(video);
    video.style
      ..opacity = '0'
      ..visibility = 'hidden';
    _events.add(video.onPlaying.listen((_) => _playAttempts = 0));
    _events.add(
      video.onEnded.listen((_) {
        if (widget.finishing) {
          _finish();
        } else if (widget.active) {
          unawaited(_play());
        }
      }),
    );
    _events.add(video.onError.listen((_) => _playbackFailed()));
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

  void _createdImage(Object element) {
    final image = element as web.HTMLImageElement;
    final source = Uri.base.resolve(
      'assets/assets/images/report-loading-animated.webp',
    );
    _styleSurface(image);
    image
      ..src = source.toString()
      ..alt = '';
    image.style
      ..backgroundImage =
          'url("${Uri.base.resolve('assets/assets/images/report-loading-poster.webp')}")'
      ..backgroundSize = 'contain'
      ..backgroundRepeat = 'no-repeat'
      ..backgroundPosition = 'center';
    image.setAttribute('aria-hidden', 'true');
    _events.add(
      image.onError.listen((_) {
        if (!mounted || !widget.active || _finished) return;
        if (++_imageAttempts > 3) {
          setState(() => _imageFailed = true);
          return;
        }
        _imageRetry?.cancel();
        _imageRetry = Timer(Duration(milliseconds: 500 * _imageAttempts), () {
          if (mounted && widget.active && !_finished) {
            image.src = source
                .replace(queryParameters: {'retry': '$_imageAttempts'})
                .toString();
          }
        });
      }),
    );
  }

  void _styleSurface(web.HTMLElement element) {
    final style = element.style;
    style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'fill'
      ..pointerEvents = 'none'
      ..transform = 'scale(1.06)'
      ..background = 'transparent'
      ..transition = 'opacity .7s ease-out';
    const mask =
        'radial-gradient(ellipse closest-side, #000 64%, #000e 77%, #0008 89%, transparent 100%),'
        'linear-gradient(to right, transparent, #000 18% 82%, transparent),'
        'linear-gradient(to bottom, #000 76%, #000b 90%, transparent)';
    style.setProperty('mask-image', mask);
    style.setProperty('mask-composite', 'intersect');
    style.setProperty('-webkit-mask-image', mask);
    style.setProperty('-webkit-mask-composite', 'source-in');
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
    if (!mounted || _finished || _failed || _playPending || !widget.active) {
      return;
    }
    _playPending = true;
    try {
      await _video?.play().toDart;
    } catch (_) {
      if (mounted && widget.active && !_finished && !_failed) {
        if (++_playAttempts < 3) {
          _playRetry?.cancel();
          _playRetry = Timer(const Duration(milliseconds: 300), () {
            if (web.document.visibilityState != 'hidden') unawaited(_play());
          });
        } else {
          _playbackFailed();
        }
      }
    } finally {
      _playPending = false;
    }
  }

  void _playbackFailed() {
    if (!mounted) return;
    _watchdog?.cancel();
    _playRetry?.cancel();
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
    _playRetry?.cancel();
    _imageRetry?.cancel();
    for (final event in _events) {
      unawaited(event.cancel());
    }
    _video?.pause();
    _video?.removeAttribute('src');
    _video?.load();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.reduced || _imageFailed
      ? Opacity(opacity: widget.active ? 1 : 0, child: const GenerationPoster())
      : _failed
      ? Opacity(
          opacity: widget.active ? 1 : 0,
          // Native image animation does not depend on media autoplay or Flutter codecs.
          child: HtmlElementView.fromTagName(
            key: const ValueKey('generation-moving-image'),
            tagName: 'img',
            onElementCreated: _createdImage,
          ),
        )
      : HtmlElementView.fromTagName(
          key: const ValueKey('generation-video'),
          tagName: 'video',
          onElementCreated: _created,
        );
}
