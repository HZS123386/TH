import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/models.dart';
import 'theme.dart';

/// Keep failed artwork recoverable without changing the surrounding layout.
class FateImage extends StatefulWidget {
  const FateImage(
    this.asset, {
    this.fit = BoxFit.contain,
    this.onPainted,
    super.key,
  });
  final String asset;
  final BoxFit fit;
  final VoidCallback? onPainted;
  @override
  State<FateImage> createState() => _FateImageState();
}

class _FateImageState extends State<FateImage> {
  int _attempt = 0;
  Timer? _retry;
  bool _paintReported = false;

  @override
  void didUpdateWidget(covariant FateImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _retry?.cancel();
      _retry = null;
      _attempt = 0;
      _paintReported = false;
    }
  }

  void _reportPaint() {
    if (_paintReported || widget.onPainted == null) return;
    _paintReported = true;
    final asset = widget.asset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.asset == asset) widget.onPainted?.call();
    });
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
        _reportPaint();
        return child;
      }
      return const ColoredBox(color: panel, child: SizedBox.expand());
    },
    errorBuilder: (context, error, stack) {
      _scheduleRetry();
      if (_attempt >= 3) _reportPaint();
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
                  tooltip: const {
                    'zh': '点击重试',
                    'th': 'ลองโหลดภาพใหม่',
                    'en': 'Reload image',
                    'vi': 'Tải lại ảnh',
                    'my': 'ပုံ ပြန်တင်မယ်',
                    'km': 'ផ្ទុករូបភាពម្ដងទៀត',
                    'lo': 'ໂຫຼດຮູບໃໝ່',
                    'ms': 'Muat semula imej',
                    'id': 'Muat ulang gambar',
                  }[Localizations.localeOf(context).languageCode],
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
    this.large = false,
    super.key,
  });
  final String label;
  final String? icon;
  final VoidCallback? onPressed;
  final bool bounce, pulse, dimDisabled, large;
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
                  minimumSize: Size.fromHeight(widget.large ? 63 : 51),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  textStyle: TextStyle(
                    fontFamily: h5FontFamily,
                    fontFamilyFallback: h5FontFallback,
                    fontSize: widget.large ? 17 : 14,
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
                      LandingIcon(widget.icon!, size: widget.large ? 22 : 19),
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
  const ThemeBoards({
    required this.copy,
    required this.viewportHeight,
    this.showHeading = true,
    super.key,
  });
  final Copy copy;
  final double viewportHeight;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    final spacing = (viewportHeight / 720).clamp(.84, 1.0).toDouble();
    return Center(
      child: ConstrainedBox(
        // Keep the two columns balanced on short, wide viewports.
        constraints: BoxConstraints(maxWidth: math.max(380.0, viewportHeight)),
        child: _panel(spacing),
      ),
    );
  }

  Widget _panel(double spacing) => Stack(
    children: [
      Positioned.fill(
        top: showHeading ? 15 * spacing : 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD9B06B)),
            borderRadius: BorderRadius.circular(12),
            gradient: const RadialGradient(
              center: Alignment.topCenter,
              radius: 1.2,
              colors: [Color(0xFF432754), Color(0xFF241632)],
            ),
          ),
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Keep the banner in flow so wrapped translations cannot cover a board.
          if (showHeading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _heading(spacing),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              8,
              (showHeading ? 4 : 8) * spacing,
              8,
              12 * spacing,
            ),
            child: Column(
              children: [
                _board(
                  'outlook',
                  const Rect.fromLTWH(121, 196, 517, 389),
                  false,
                  spacing: spacing,
                ),
                SizedBox(height: 10 * spacing),
                _board(
                  'highlights',
                  const Rect.fromLTWH(656, 644, 517, 443),
                  true,
                  spacing: spacing,
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  Widget _heading(double spacing) => Container(
    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 6 * spacing),
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
          child: const LandingIcon('cloud', size: 21, color: Color(0xFF341D38)),
        ),
      ],
    ),
  );

  Widget _board(
    String key,
    Rect crop,
    bool reverse, {
    required double spacing,
  }) {
    final titles = objects(
      object(copy.data['jyThemes'])[key],
    ).map((item) => text(item[copy.language]));
    final labels = Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 7 * spacing,
      children: [
        for (final title in titles)
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: 33 * spacing),
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
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal: 2,
                vertical: 3 * spacing,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF553767), Color(0xFF38244B)],
                ),
              ),
              child: Text(
                title,
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
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8 * spacing),
      decoration: BoxDecoration(
        color: reverse ? const Color(0xFF39224E) : const Color(0xFF3A234C),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x9CBF975D)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final gap = math.min(9 * spacing, box.maxWidth);
          final ratio = reverse ? 7 / 6 : 4 / 3;
          final width = (box.maxWidth - gap) * spacing / 2;
          final art = _artwork(crop, Size(width, width / ratio));
          final spacer = SizedBox(width: gap);
          return Row(
            children: reverse
                ? [Expanded(child: labels), spacer, art]
                : [art, spacer, Expanded(child: labels)],
          );
        },
      ),
    );
  }

  Widget _artwork(Rect crop, Size size) {
    final scale = math.max(size.width / crop.width, size.height / crop.height);
    return SizedBox.fromSize(
      size: size,
      child: ClipPath(
        clipper: _Corners(),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: -crop.left * scale + (size.width - crop.width * scale) / 2,
              top: -crop.top * scale + (size.height - crop.height * scale) / 2,
              width: 1315 * scale,
              height: 1197 * scale,
              child: const FateImage(
                'assets/images/theme-thai-artwork.jpg',
                fit: BoxFit.fill,
              ),
            ),
          ],
        ),
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
    this.themes,
    this.locked = true,
    this.western = false,
    this.labelsInside = false,
    this.onTap,
    super.key,
  });
  final Copy copy;
  final List<Json>? themes;
  final bool locked;
  final bool western;
  final bool labelsInside;
  final ValueChanged<String>? onTap;
  @override
  Widget build(BuildContext context) {
    final items =
        themes ??
        (locked
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
                    'key': key,
                    copy.language: copy.t(
                      'jy',
                      'report.${western ? 'westernSections' : 'sections'}.$key',
                    ),
                  },
              ]);
    return LayoutBuilder(
      builder: (context, box) {
        if (!locked) {
          final columns = box.maxWidth < 250 ? 1 : 2;
          return Column(
            children: [
              for (
                var row = 0;
                row < (items.length / columns).ceil();
                row++
              ) ...[
                if (row > 0) const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) const SizedBox(width: 10),
                        Expanded(
                          child: row * columns + column < items.length
                              ? _sectionLink(
                                  items[row * columns + column],
                                  row * columns + column + 1,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        }
        const gap = 10.0;
        final badgeColumns = labelsInside || box.maxWidth >= 300 ? 3 : 2;
        final width = (box.maxWidth - gap * (badgeColumns - 1)) / badgeColumns;
        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _badge(
                  item,
                  math.min(width, labelsInside ? 124.0 : 88.0),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Color> _colors(String id) => switch (id) {
    'natal' => const [Color(0xFF368693), Color(0xFF12313F)],
    'love' => const [Color(0xFFAA526B), Color(0xFF3C1631)],
    'career' => const [Color(0xFF3B8464), Color(0xFF102E2C)],
    'warning' ||
    'risk' ||
    'opportunities' => const [Color(0xFFA15A45), Color(0xFF421F27)],
    'advice' || 'plan' => const [Color(0xFF526FBD), Color(0xFF1B244E)],
    'partnership' => const [Color(0xFF9075B8), Color(0xFF30203F)],
    _ => const [Color(0xFFA97631), Color(0xFF3B230E)],
  };

  String _art(String id) => switch (id) {
    'judgment' => 'love',
    'basis' => 'natal',
    'wealth' => 'finance',
    'warning' || 'risk' => 'opportunities',
    'plan' => 'advice',
    _ => id,
  };

  Widget _sectionLink(Json item, int number) {
    final id = text(item['key']), label = text(item[copy.language]);
    final colors = _colors(id);
    final action = onTap == null ? null : () => onTap!(id);
    return Semantics(
      button: action != null,
      label: label,
      child: Material(
        key: ValueKey('report-section-$id'),
        color: const Color(0xFF291D3A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.first.withValues(alpha: .45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: colors),
                      border: Border.all(
                        color: colors.first.withValues(alpha: .6),
                      ),
                    ),
                    child: ClipOval(
                      child: SvgPicture.asset(
                        'assets/images/badges/${_art(id)}.svg',
                        width: 30,
                        height: 30,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          number.toString().padLeft(2, '0'),
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.1,
                            color: lavender,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: cream,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: gold,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(Json item, double size) {
    final id = text(item['key']);
    final colors = _colors(id);
    final label = Text(
      text(item[copy.language]),
      textAlign: TextAlign.center,
      maxLines: labelsInside ? 2 : null,
      overflow: labelsInside ? TextOverflow.ellipsis : null,
      style: TextStyle(
        fontSize: labelsInside ? 14 : 12,
        height: 1.35,
        color: const Color(0xFFFFF0D2),
        fontWeight: FontWeight.w700,
      ),
    );
    final symbol = Text(
      text(item['icon']),
      style: const TextStyle(color: Color(0xFFF6D096), fontSize: 18),
    );
    return Semantics(
      button: onTap != null,
      label: text(item[copy.language]),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(id),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE8BC7E)),
                gradient: RadialGradient(
                  center: const Alignment(0, -.65),
                  radius: .85,
                  colors: colors,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (labelsInside)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x65F5D08F)),
                        ),
                      ),
                    ),
                  ClipOval(
                    child: SvgPicture.asset(
                      'assets/images/badges/${_art(id)}.svg',
                      width: size,
                      height: size,
                    ),
                  ),
                  if (labelsInside)
                    SizedBox(
                      width: size * .8,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          symbol,
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(width: size * .8, child: label),
                            ),
                          ),
                          if (locked)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFF573476),
                                shape: BoxShape.circle,
                              ),
                              child: const LandingIcon(
                                'lock',
                                size: 13,
                                color: Color(0xFFFFE5A3),
                              ),
                            ),
                        ],
                      ),
                    )
                  else ...[
                    symbol,
                    if (locked)
                      const Positioned(
                        bottom: 4,
                        child: LandingIcon(
                          'lock',
                          size: 16,
                          color: Color(0xFFFFE5A3),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (!labelsInside) ...[const SizedBox(height: 6), label],
          ],
        ),
      ),
    );
  }
}
