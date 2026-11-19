import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/models.dart';
import '../ui/theme.dart';

class PhoneCountry {
  PhoneCountry(Json data)
    : iso2 = text(data['iso2']),
      dialCode = text(data['dialCode']),
      names = {
        for (final lang in ['zh', 'th', 'en']) lang: text(data[lang]),
      };

  final String iso2, dialCode;
  final Map<String, String> names;
  String name(String language) => names[language] ?? names['en']!;
  String get flagAsset => 'assets/images/flags/${iso2.toLowerCase()}.svg';

  bool matches(String query) {
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[\s+()-]'), '');
    final needle = normalize(query);
    return [
      iso2,
      dialCode,
      ...names.values,
    ].any((value) => normalize(value).contains(needle));
  }
}

class PhoneCountryPicker extends StatefulWidget {
  const PhoneCountryPicker({
    required this.copy,
    required this.countries,
    required this.country,
    required this.onChanged,
    this.enabled = true,
    this.showName = false,
    super.key,
  });

  final Copy copy;
  final List<PhoneCountry> countries;
  final PhoneCountry country;
  final ValueChanged<PhoneCountry> onChanged;
  final bool enabled, showName;

  @override
  State<PhoneCountryPicker> createState() => _PhoneCountryPickerState();
}

class _PhoneCountryPickerState extends State<PhoneCountryPicker> {
  final _portal = OverlayPortalController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode(), _anchorFocus = FocusNode();
  bool _scrolling = false;

  void _setOpen(bool open) {
    if (open == _portal.isShowing || (open && !widget.enabled)) return;
    setState(() {
      if (open) {
        _search.clear();
        _portal.show();
      } else {
        _portal.hide();
        _searchFocus.unfocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PhoneCountryPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _portal.isShowing) {
      _portal.hide();
      _searchFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _anchorFocus.dispose();
    super.dispose();
  }

  void _reserveSpace() {
    final scroll = Scrollable.maybeOf(context)?.position;
    if (_scrolling ||
        scroll == null ||
        scroll.pixels >= scroll.maxScrollExtent - 1) {
      return;
    }
    _scrolling = true;
    // Scroll the existing dialog when the keyboard leaves too little room below the field.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (mounted && _portal.isShowing && scroll.hasPixels) {
          await scroll.animateTo(
            scroll.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      } finally {
        _scrolling = false;
      }
    });
  }

  Widget _flag(PhoneCountry value) => SvgPicture.asset(
    value.flagAsset,
    width: 24,
    height: 18,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );

  Widget _positionMenu(BuildContext context, OverlayChildLayoutInfo layout) {
    final field = MatrixUtils.transformRect(
      layout.childPaintTransform,
      Offset.zero & layout.childSize,
    );
    final viewport = MediaQueryData.fromView(View.of(context));
    final bottom =
        (viewport.size.height - viewport.viewInsets.bottom).clamp(
          0.0,
          layout.overlaySize.height,
        ) -
        viewport.padding.bottom -
        8;
    final available = (bottom - field.bottom - 5).clamp(0.0, 280.0);
    if (available < 160) _reserveSpace();
    final width = (viewport.size.width < 360 ? field.width : 320.0).clamp(
      0.0,
      layout.overlaySize.width - 16,
    );
    final left = field.left.clamp(8.0, layout.overlaySize.width - width - 8);
    return Positioned(
      left: left,
      top: field.bottom + 5,
      width: width,
      height: available.clamp(72.0, 280.0),
      child: TextFieldTapRegion(groupId: _portal, child: _menu()),
    );
  }

  Widget _menu() {
    final c = widget.copy;
    final matches = widget.countries
        .where((item) => item.matches(_search.text))
        .toList();
    return Material(
      key: const ValueKey('phone-country-menu'),
      color: panel,
      elevation: 12,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: line),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              height: 44,
              child: TextField(
                key: const ValueKey('phone-country-search'),
                groupId: _portal,
                controller: _search,
                focusNode: _searchFocus,
                onChanged: (_) => setState(() {}),
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: cream, fontSize: 14),
                decoration: InputDecoration(
                  hintText: c.t('checkout', 'countrySearch'),
                  hintStyle: const TextStyle(color: lavender, fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: lavender,
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 30),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: line),
          Expanded(
            child: matches.isEmpty
                ? ListView(
                    primary: false,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        c.t('checkout', 'countryEmpty'),
                        style: const TextStyle(color: lavender, fontSize: 13),
                      ),
                    ],
                  )
                : ListView.builder(
                    primary: false,
                    padding: EdgeInsets.zero,
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final item = matches[index];
                      return ListTile(
                        key: ValueKey('phone-country-${item.iso2}'),
                        selected: item.iso2 == widget.country.iso2,
                        selectedTileColor: gold.withValues(alpha: .10),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        minLeadingWidth: 24,
                        horizontalTitleGap: 10,
                        leading: _flag(item),
                        title: Text(
                          item.name(c.language),
                          style: const TextStyle(color: cream, fontSize: 13),
                        ),
                        trailing: Text(
                          '+${item.dialCode}',
                          style: const TextStyle(color: gold, fontSize: 13),
                        ),
                        onTap: () {
                          _setOpen(false);
                          _anchorFocus.requestFocus();
                          widget.onChanged(item);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy, country = widget.country;
    final label = '${country.name(copy.language)} +${country.dialCode}';
    return CallbackShortcuts(
      bindings: {
        if (_portal.isShowing)
          const SingleActivator(LogicalKeyboardKey.escape): () => _setOpen(false),
      },
      child: TextFieldTapRegion(
        groupId: _portal,
        consumeOutsideTaps: _portal.isShowing,
        onTapOutside: (_) => _setOpen(false),
        child: OverlayPortal.overlayChildLayoutBuilder(
          controller: _portal,
          overlayChildBuilder: _positionMenu,
          child: Semantics(
            button: true,
            enabled: widget.enabled,
            label: '${copy.t('checkout', 'nationCode')} $label',
            excludeSemantics: true,
            child: Tooltip(
              message: _portal.isShowing ? '' : label,
              child: InkWell(
                focusNode: _anchorFocus,
                borderRadius: BorderRadius.circular(8),
                onTap: widget.enabled
                    ? () => _setOpen(!_portal.isShowing)
                    : null,
                child: InputDecorator(
                  decoration: InputDecoration(
                    enabled: widget.enabled,
                    labelText: copy.t('checkout', 'nationCode'),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                  child: Row(
                    children: [
                      _flag(country),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.showName ? label : '+${country.dialCode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: cream, fontSize: 14),
                        ),
                      ),
                      Icon(
                        _portal.isShowing
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 16,
                        color: lavender,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
