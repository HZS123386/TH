import 'dart:async';
import 'package:flutter/material.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';

class BirthplaceFields extends StatefulWidget {
  const BirthplaceFields({
    required this.h5,
    required this.onSelected,
    super.key,
  });
  final H5Controller h5;
  final ValueChanged<Place?> onSelected;
  @override
  State<BirthplaceFields> createState() => _BirthplaceFieldsState();
}

class _BirthplaceFieldsState extends State<BirthplaceFields> {
  final _provinceText = TextEditingController();
  final _menus = {'birth-province': OverlayPortalController()};
  String _provinceQuery = '', _open = '', _language = '';
  Place? _province;
  Copy get c => widget.h5.copy;

  @override
  void dispose() {
    _provinceText.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BirthplaceFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_language != c.language) {
      _language = c.language;
      if (_province != null) _provinceText.text = _province!.name(c.language);
    }
  }

  void _setOpen(String id) {
    if (_open == id) return;
    _menus[_open]?.hide();
    _open = id;
    _menus[id]?.show();
    if (id.isNotEmpty) widget.h5.trackActivity('birth_form', 'select_birthplace');
  }

  Widget _positionMenu(
    BuildContext context,
    OverlayChildLayoutInfo layout,
    OverlayPortalController portal,
    String id,
    Widget options,
  ) {
    const gap = 5.0, menuHeight = 185.0;
    final field = MatrixUtils.transformRect(
      layout.childPaintTransform,
      Offset.zero & layout.childSize,
    );
    final viewport = MediaQueryData.fromView(View.of(context));
    final visibleBottom = viewport.size.height - viewport.viewInsets.bottom;
    final bottom = (visibleBottom < layout.overlaySize.height
        ? visibleBottom : layout.overlaySize.height) - viewport.padding.bottom - 8;
    final top = viewport.padding.top + 8;
    if (field.bottom <= top || field.top >= bottom) {
      return const SizedBox.shrink();
    }
    final above = (field.top - top - gap).clamp(0.0, menuHeight);
    final below = (bottom - field.bottom - gap).clamp(0.0, menuHeight);
    final opensDown = below >= 120 || below >= above;
    return Positioned(
      left: field.left,
      width: field.width,
      top: opensDown ? field.bottom + gap : null,
      bottom: opensDown ? null : layout.overlaySize.height - field.top + gap,
      child: ConstrainedBox(
        key: ValueKey('$id-options'),
        constraints: BoxConstraints(maxHeight: opensDown ? below : above),
        child: TextFieldTapRegion(
          groupId: portal,
          child: Material(type: MaterialType.transparency, child: options),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _language = c.language;
    Widget field(
      String id,
      String label,
      TextEditingController controller,
      String hint,
      VoidCallback open,
      ValueChanged<String> edit,
      Widget options,
    ) {
      final portal = _menus[id]!;
      return Focus(
        onFocusChange: (focused) {
          // Web focus can arrive before an arrow press; only explicit taps open it.
          if (mounted && !focused && _open == id) {
            setState(() => _setOpen(''));
          }
        },
        // Mouse-down on a suggestion must not blur and remove it before mouse-up.
        child: TextFieldTapRegion(
          groupId: portal,
          onTapOutside: (_) {
            if (_open == id && mounted) setState(() => _setOpen(''));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              OverlayPortal.overlayChildLayoutBuilder(
                controller: portal,
                overlayChildBuilder: (context, layout) =>
                    _positionMenu(context, layout, portal, id, options),
                child: SizedBox(
                  height: 46,
                  child: TextFormField(
                    key: ValueKey(id),
                    groupId: portal,
                    controller: controller,
                    style: const TextStyle(fontSize: 13),
                    autocorrect: false,
                    maxLength: 80,
                    onTap: open,
                    onChanged: edit,
                    decoration: InputDecoration(
                      hintText: hint,
                      counterText: '',
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 36,
                        maxWidth: 36,
                      ),
                      suffixIcon: IconButton(
                        tooltip: label,
                        onPressed: () =>
                            setState(() => _setOpen(_open == id ? '' : id)),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 19,
                          color: gold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field(
          'birth-province',
          c.t('jy', 'region'),
          _provinceText,
          c.t('jy', 'thaiRegionPrompt'),
          () => setState(() => _setOpen('birth-province')),
          (value) => setState(() {
            _province = null;
            _provinceQuery = value;
            widget.onSelected(null);
            _setOpen('birth-province');
          }),
          PlacePicker(
            h5: widget.h5,
            query: _provinceQuery,
            onSelected: (value) => setState(() {
              _province = value;
              _provinceText.text = value.name(c.language);
              _provinceQuery = '';
              _setOpen('');
              widget.onSelected(value);
            }),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          c.t('jy', 'placeHint'),
          style: const TextStyle(fontSize: 10, height: 1.8, color: lavender),
        ),
      ],
    );
  }
}

class PlacePicker extends StatefulWidget {
  const PlacePicker({
    required this.h5,
    this.query = '',
    required this.onSelected,
    super.key,
  });
  final H5Controller h5;
  final String query;
  final ValueChanged<Place> onSelected;
  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  CancelToken? _request;
  List<Place> _items = [];
  List<Place>? _provinces;
  bool _busy = true;
  String _error = '';
  Copy get c => widget.h5.copy;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant PlacePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && _provinces != null) {
      _items = _provinces!
          .where((place) => place.matches(widget.query))
          .toList();
    }
  }

  Future<void> _load() async {
    _request?.cancel();
    final token = CancelToken();
    _request = token;
    setState(() {
      _busy = true;
      _error = '';
      _items = [];
    });
    try {
      _provinces ??= await widget.h5.repository.provinces('TH', token);
      if (!mounted || token.cancelled) return;
      await widget.h5.prepareText(
        _provinces!.map((place) => place.name(c.language)).join(),
      );
      if (!mounted || token.cancelled) return;
      setState(() {
        _items = _provinces!
            .where((place) => place.matches(widget.query))
            .toList();
        _busy = false;
      });
    } catch (error) {
      if (mounted && !token.cancelled) {
        setState(() {
          _busy = false;
          _error = widget.h5.message(error);
        });
      }
    }
  }

  @override
  void dispose() {
    _request?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxHeight: 185),
    decoration: BoxDecoration(
      color: const Color(0xFF171027),
      border: Border.all(color: const Color(0x40E4BC78)),
      borderRadius: BorderRadius.circular(9),
    ),
    child: ListView(
      primary: false,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: [
        if (_busy && _items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              c.t('jy', 'regionPending'),
              style: const TextStyle(fontSize: 11, color: lavender),
            ),
          ),
        for (final place in _items) _option(place),
        if (!_busy && _items.isEmpty && _error.isEmpty)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              c.t('ui', 'noCity'),
              style: const TextStyle(fontSize: 11, color: lavender),
            ),
          ),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _error,
              style: const TextStyle(fontSize: 11, color: lavender),
            ),
          ),
        if (_error.isNotEmpty)
          TextButton(
            onPressed: () => _load(),
            child: Text(
              c.t('jy', 'regionRetry'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    ),
  );
  Widget _option(Place place) => InkWell(
    onTap: () => widget.onSelected(place),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            place.name(c.language),
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    ),
  );
}
