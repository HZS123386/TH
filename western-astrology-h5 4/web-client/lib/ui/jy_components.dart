import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/models.dart';
import 'theme.dart';

/// Keep failed artwork recoverable without changing the surrounding layout.
class FateImage extends StatefulWidget {
  const FateImage(this.asset, {this.fit = BoxFit.contain, super.key});
  final String asset;
  final BoxFit fit;
  @override
  State<FateImage> createState() => _FateImageState();
}

class _FateImageState extends State<FateImage> {
  int _attempt = 0;
  Timer? _retry;

  @override
  void didUpdateWidget(covariant FateImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _retry?.cancel();
      _retry = null;
      _attempt = 0;
    }
  }

  void _scheduleRetry() {
    if (_retry != null || _attempt >= 3) return;
    _retry = Timer(
      Duration(milliseconds: 500 * (_attempt + 1)),
      () => unawaited(_reload()),
    );
  }

  Future<void> _reload({bool manual = false}) async {
    if (!mounted) return;
    final asset = widget.asset;
    // A failed decoder can stay in the image cache until it is explicitly evicted.
    try {
      await AssetImage(
        asset,
      ).evict(configuration: createLocalImageConfiguration(context));
    } catch (_) {
      // A failed asset manifest must also get another image resolve attempt.
    }
    if (!mounted || asset != widget.asset) return;
    _retry = null;
    setState(() => _attempt = manual ? 0 : _attempt + 1);
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Image.asset(
    widget.asset,
    key: ValueKey((widget.asset, _attempt)),
    fit: widget.fit,
    frameBuilder: (context, child, frame, synchronous) {
      if (frame != null || synchronous) {
        _retry?.cancel();
        _retry = null;
        return child;
      }
      return const ColoredBox(color: panel, child: SizedBox.expand());
    },
    errorBuilder: (context, error, stack) {
      _scheduleRetry();
      return ColoredBox(
        color: panel,
        child: Center(
          child: _attempt < 3
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              : IconButton(
                  tooltip: Localizations.localeOf(context).languageCode == 'zh'
                      ? '点击重试'
                      : 'ลองโหลดภาพใหม่',
                  icon: const Icon(Icons.refresh_rounded, color: gold),
                  onPressed: () => unawaited(_reload(manual: true)),
                ),
        ),
      );
    },
  );
}

class FateBrand extends StatelessWidget {
  const FateBrand({this.compact = false, super.key});
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'FATE',
    image: true,
    child: Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: Image.asset(
        compact
            ? 'assets/images/fate-brand-gold.png'
            : 'assets/images/fate-brand.png',
        height: compact ? 18 : 32,
        excludeFromSemantics: true,
      ),
    ),
  );
}

class LandingIcon extends StatelessWidget {
  const LandingIcon(this.name, {this.size = 19, this.color, super.key});
  final String name;
  final double size;
  final Color? color;
  static const _paths = {
    'book':
        'M12 7v14m0-14C9 4 5 4 2 5v14c4-1 7 0 10 2 3-2 6-3 10-2V5c-3-1-7-1-10 2Z',
    'lock': 'M7 10V7a5 5 0 0 1 10 0v3M5 10h14v11H5zM12 15v2',
    'download':
        'M12 3v12m-5-5 5 5 5-5M4 16v4a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-4',
    'history': 'M3 12a9 9 0 1 1 3 6.7M3 5v7h7m2-5v5l3 2',
    'cloud':
        'M2 15h16a3 3 0 1 0-2.8-4A4.8 4.8 0 0 0 6 12a2.2 2.2 0 0 0-4 1.4M5 18h14m-7-6a1.5 1.5 0 0 0-3 0',
  };
  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="${_hex(color ?? IconTheme.of(context).color ?? gold)}" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><path d="${_paths[name]}"/></svg>',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
  String _hex(Color c) => '#${c.toARGB32().toRadixString(16).substring(2)}';
}

class JYCard extends StatelessWidget {
  const JYCard({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    this.radius = 14,
    this.colors = const [Color(0xFF322243), Color(0xFF1E142E)],
    this.borderColor = const Color(0x60E4BC78),
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final List<Color> colors;
  final Color borderColor;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      border: Border.all(color: borderColor),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x660C061E),
          offset: Offset(0, 8),
          blurRadius: 22,
        ),
      ],
    ),
    child: child,
  );
}

/// The same bounce and download pulse used by the JY stylesheet.
class JYButton extends StatefulWidget {
  const JYButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.bounce = false,
    this.pulse = false,
    this.dimDisabled = true,
    super.key,
  });
  final String label;
  final String? icon;
  final VoidCallback? onPressed;
  final bool bounce, pulse, dimDisabled;
  @override
  State<JYButton> createState() => _JYButtonState();
}

class _JYButtonState extends State<JYButton>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(vsync: this);
  void _update() {
    if ((widget.bounce || widget.pulse) &&
        widget.onPressed != null &&
        !MediaQuery.disableAnimationsOf(context)) {
      _motion.duration = Duration(milliseconds: widget.pulse ? 1800 : 1300);
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(covariant JYButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) {
      final t = _motion.value;
      double scale = 1, dy = 0;
      if (widget.pulse) {
        scale += math.pow(math.sin(t * math.pi), 2) * .045;
      }
      if (widget.bounce) {
        final (start, end, local) = t <= .45
            ? (0, 1, t / .45)
            : t <= .74
            ? (1, 2, (t - .45) / .29)
            : (2, 0, (t - .74) / .26);
        final eased = Curves.easeInOut.transform(local);
        const scales = [1.0, 1.045, .99], offsets = [0.0, -8.0, 2.0];
        scale = scales[start] + (scales[end] - scales[start]) * eased;
        dy = offsets[start] + (offsets[end] - offsets[start]) * eased;
      }
      return Transform.translate(
        offset: Offset(0, dy),
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: widget.onPressed == null && widget.dimDisabled ? .65 : 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE48F)),
                gradient: LinearGradient(
                  colors: widget.pulse
                      ? const [
                          Color(0xFF442B56),
                          Color(0xFF543569),
                          Color(0xFF442B56),
                        ]
                      : widget.bounce
                      ? const [
                          Color(0xFFECAA28),
                          Color(0xFFFFDC65),
                          Color(0xFFF3B830),
                        ]
                      : const [
                          Color(0xFFD9A759),
                          Color(0xFFF3D69E),
                          Color(0xFFDEB36D),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x55E9AC3A),
                    blurRadius: 16 + (scale - 1) * 120,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: widget.onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: widget.pulse
                      ? const Color(0xFFFFE3AA)
                      : const Color(0xFF341D38),
                  disabledForegroundColor: const Color(0xFF341D38),
                  shadowColor: Colors.transparent,
                  minimumSize: const Size.fromHeight(51),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  textStyle: const TextStyle(
                    fontFamily: h5FontFamily,
                    fontFamilyFallback: h5FontFallback,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      LandingIcon(widget.icon!),
                      const SizedBox(width: 9),
                    ],
                    Flexible(
                      child: Text(widget.label, textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ThemeBoards extends StatelessWidget {
  const ThemeBoards({required this.copy, super.key});
  final Copy copy;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        margin: const EdgeInsets.only(top: 15),
        padding: const EdgeInsets.fromLTRB(8, 22, 8, 9),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD9B06B)),
          borderRadius: BorderRadius.circular(12),
          gradient: const RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [Color(0xFF432754), Color(0xFF241632)],
          ),
        ),
        child: Column(
          children: [
            _board('outlook', const Rect.fromLTWH(121, 196, 517, 389), false),
            const SizedBox(height: 8),
            _board('highlights', const Rect.fromLTWH(656, 644, 517, 443), true),
          ],
        ),
      ),
      Positioned(
        top: 0,
        left: 6,
        right: 6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFFFE48F)),
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFFECAA28), Color(0xFFFFDC65), Color(0xFFF3B830)],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LandingIcon('cloud', size: 21, color: Color(0xFF341D38)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  copy.t('jy', 'topicLabel'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF341D38),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Transform.flip(
                flipX: true,
                child: const LandingIcon(
                  'cloud',
                  size: 21,
                  color: Color(0xFF341D38),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Widget _board(String key, Rect crop, bool reverse) {
    final themes = objects(object(copy.data['jyThemes'])[key]);
    final art = Expanded(
      child: ClipPath(
        clipper: _Corners(),
        child: AspectRatio(
          aspectRatio: reverse ? 7 / 6 : 4 / 3,
          child: LayoutBuilder(
            builder: (context, box) {
              final scale = math.max(
                box.maxWidth / crop.width,
                box.maxHeight / crop.height,
              );
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left:
                        -crop.left * scale +
                        (box.maxWidth - crop.width * scale) / 2,
                    top:
                        -crop.top * scale +
                        (box.maxHeight - crop.height * scale) / 2,
                    width: 1315 * scale,
                    height: 1197 * scale,
                    child: FateImage(
                      'assets/images/theme-thai-artwork.jpg',
                      fit: BoxFit.fill,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    final labels = Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in themes)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 2.5),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: LinearGradient(
                  colors: reverse
                      ? const [
                          Color(0xFF805D9C),
                          Color(0xFFC6A2DB),
                          Color(0xFF805D9C),
                        ]
                      : const [
                          Color(0xFFA57246),
                          Color(0xFFF1CD90),
                          Color(0xFFAD7D52),
                        ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF553767), Color(0xFF38244B)],
                  ),
                ),
                child: Text(
                  text(item[copy.language]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFE1AB),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: reverse ? const Color(0xFF39224E) : const Color(0xFF3A234C),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x9CBF975D)),
      ),
      child: Row(
        children: reverse
            ? [labels, const SizedBox(width: 7), art]
            : [art, const SizedBox(width: 7), labels],
      ),
    );
  }
}

class _Corners extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(6, 0)
    ..lineTo(s.width - 6, 0)
    ..lineTo(s.width, 6)
    ..lineTo(s.width, s.height - 6)
    ..lineTo(s.width - 6, s.height)
    ..lineTo(6, s.height)
    ..lineTo(0, s.height - 6)
    ..lineTo(0, 6)
    ..close();
  @override
  bool shouldReclip(_Corners oldClipper) => false;
}

class ReportBadges extends StatelessWidget {
  const ReportBadges({
    required this.copy,
    this.locked = true,
    this.western = false,
    this.onTap,
    super.key,
  });
  final Copy copy;
  final bool locked;
  final bool western;
  final ValueChanged<String>? onTap;
  @override
  Widget build(BuildContext context) {
    final items = locked
        ? [
            ...objects(object(copy.data['jyThemes'])['outlook']),
            ...objects(object(copy.data['jyThemes'])['highlights']),
          ]
        : [
            for (final key
                in western
                    ? ['natal', 'career', 'wealth', 'love', 'risk', 'plan']
                    : [
                        'overall',
                        'natal',
                        'love',
                        'career',
                        'opportunities',
                        'partnership',
                      ])
              {
                'id': key,
                copy.language: copy.t(
                  'jy',
                  'report.${western ? 'westernSections' : 'sections'}.$key',
                ),
                'icon': {
                  'overall': '✦',
                  'natal': '☉',
                  'love': '♡',
                  'career': '◇',
                  'opportunities': '✧',
                  'partnership': '☽',
                  'wealth': '◇',
                  'risk': '✧',
                  'plan': '✦',
                }[key],
              },
          ];
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - 20) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Center(child: _badge(item, math.min(width, 106))),
              ),
          ],
        );
      },
    );
  }

  Widget _badge(Json item, double size) {
    final id = text(item['id']);
    final colors = switch (id) {
      'natal' => const [Color(0xFF368693), Color(0xFF12313F)],
      'love' => const [Color(0xFFAA526B), Color(0xFF3C1631)],
      'career' => const [Color(0xFF3B8464), Color(0xFF102E2C)],
      'warning' => const [Color(0xFFA15A45), Color(0xFF421F27)],
      'advice' => const [Color(0xFF526FBD), Color(0xFF1B244E)],
      _ => const [Color(0xFFA97631), Color(0xFF3B230E)],
    };
    return Semantics(
      button: onTap != null,
      label: text(item[copy.language]),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(id),
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE8BC7E)),
            gradient: RadialGradient(
              center: const Alignment(0, -.65),
              radius: .85,
              colors: locked
                  ? colors
                  : const [Color(0xFF573B64), Color(0xFF271934)],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x66CBA76F)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (locked)
                  ClipOval(
                    child: SvgPicture.asset(
                      'assets/images/badges/${id == 'warning' ? 'opportunities' : id}.svg',
                      width: size,
                      height: size,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        text(item['icon']),
                        style: const TextStyle(
                          color: Color(0xFFF6D096),
                          fontSize: 18,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        text(item[copy.language]),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.25,
                          color: Color(0xFFFFF0D2),
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(
                              color: Color(0xFF160C1E),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      if (locked) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.all(1),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF593B73),
                          ),
                          child: const LandingIcon(
                            'lock',
                            size: 16,
                            color: Color(0xFFFFE5A3),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
