import 'dart:async';
import 'package:flutter/material.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';

class BirthplaceFields extends StatefulWidget {
  const BirthplaceFields({
    required this.h5,
    required this.country,
    required this.onSelected,
    this.initialPlace,
    super.key,
  });
  final H5Controller h5;
  final String country;
  final ValueChanged<Place?> onSelected;
  final Place? initialPlace;
  @override
  State<BirthplaceFields> createState() => _BirthplaceFieldsState();
}

class _BirthplaceFieldsState extends State<BirthplaceFields> {
  final _cityText = TextEditingController();
  final _menu = OverlayPortalController();
  String _cityQuery = '';
  bool _open = false;
  Place? _city;
  final _initialPlaceRequest = CancelToken();
  Copy get c => widget.h5.copy;

  @override
  void initState() {
    super.initState();
    unawaited(widget.h5.repository.warmCities(widget.country));
    final place = widget.initialPlace;
    if (place == null || place.country != widget.country) return;
    _restorePlace(place);
    if (place.id.isNotEmpty && place.json['placeType'] == null) {
      unawaited(_resolveInitialPlace(place));
    }
  }

  void _restorePlace(Place place) {
    _city = place;
    _cityText.text = place.name(c.language);
  }

  Future<void> _resolveInitialPlace(Place initial) async {
    try {
      final query = Uri(
        queryParameters: {
          'country': initial.country,
          'level': 'detail',
          'query': initial.id,
        },
      ).query;
      final result = object(
        await widget.h5.repository.request(
          '/api/thai-locations?$query',
          _initialPlaceRequest,
          owned: false,
        ),
      );
      final place = Place(object(result['resolved']));
      if (!mounted ||
          _initialPlaceRequest.cancelled ||
          !identical(_city, initial) ||
          place.id != initial.id ||
          place.zone != initial.zone ||
          place.country != widget.country) {
        return;
      }
      setState(() => _restorePlace(place));
      widget.onSelected(place);
    } catch (_) {
      // Existing identifiers/coordinates remain usable without extra place metadata.
    }
  }

  void _setOpen(bool value) {
    if (_open == value) return;
    _open = value;
    if (value) {
      _menu.show();
      widget.h5.trackActivity('birth_form', 'select_birthplace');
    } else {
      _menu.hide();
    }
  }

  Widget _floatingOptions(
    BuildContext context,
    OverlayChildLayoutInfo layout,
    Widget options,
  ) {
    if (!_open) return const SizedBox.shrink();
    final anchor = MatrixUtils.transformRect(
      layout.childPaintTransform,
      Offset.zero & layout.childSize,
    );
    // Scaffold may remove inherited keyboard insets after resizing its body.
    final view = MediaQueryData.fromView(View.of(context));
    final top = view.padding.top + 8;
    final visibleBottom = view.size.height - view.viewInsets.bottom;
    final bottom =
        (visibleBottom < layout.overlaySize.height
            ? visibleBottom
            : layout.overlaySize.height) -
        view.padding.bottom -
        8;
    if (anchor.bottom < top || anchor.top > bottom) {
      return const SizedBox.shrink();
    }
    final below = (bottom - anchor.bottom - 5).clamp(0.0, 185.0);
    final above = (anchor.top - top - 5).clamp(0.0, 185.0);
    final upward = below < 120 && above > below;
    return Positioned(
      left: anchor.left,
      top: upward ? null : anchor.bottom + 5,
      bottom: upward ? layout.overlaySize.height - anchor.top + 5 : null,
      width: anchor.width,
      child: ConstrainedBox(
        key: const ValueKey('birth-city-options'),
        constraints: BoxConstraints(maxHeight: upward ? above : below),
        child: TextFieldTapRegion(
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            borderRadius: BorderRadius.circular(9),
            clipBehavior: Clip.antiAlias,
            child: options,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _initialPlaceRequest.cancel();
    _cityText.dispose();
    super.dispose();
  }

  void _select(Place place) {
    if (place.country != widget.country) return;
    setState(() {
      _cityQuery = '';
      _restorePlace(place);
      _setOpen(false);
    });
    widget.onSelected(place);
  }

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (focused) {
      if (mounted && !focused && _open) setState(() => _setOpen(false));
    },
    // Keep the suggestion in the same tap region as its text field.
    child: TextFieldTapRegion(
      onTapOutside: (_) {
        if (mounted && _open) setState(() => _setOpen(false));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '⌖  ${c.t('jy', 'city')}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          OverlayPortal.overlayChildLayoutBuilder(
            controller: _menu,
            overlayChildBuilder: (context, layout) => _floatingOptions(
              context,
              layout,
              PlacePicker(
                h5: widget.h5,
                country: widget.country,
                query: _cityQuery,
                onSelected: _select,
              ),
            ),
            child: SizedBox(
              height: 46,
              child: TextFormField(
                key: const ValueKey('birth-city'),
                controller: _cityText,
                style: const TextStyle(fontSize: 13),
                autocorrect: false,
                maxLength: 80,
                onTap: () => setState(() => _setOpen(true)),
                onChanged: (value) {
                  setState(() {
                    _cityQuery = value;
                    _city = null;
                    _setOpen(true);
                  });
                  widget.onSelected(null);
                },
                decoration: InputDecoration(
                  hintText: c.t('jy', 'citySearch'),
                  counterText: '',
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    maxWidth: 36,
                  ),
                  suffixIcon: IconButton(
                    tooltip: c.t('jy', 'city'),
                    onPressed: () => setState(() => _setOpen(!_open)),
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

class PlacePicker extends StatefulWidget {
  const PlacePicker({
    required this.h5,
    required this.country,
    this.query = '',
    required this.onSelected,
    super.key,
  });
  final H5Controller h5;
  final String country;
  final String query;
  final ValueChanged<Place> onSelected;
  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  CancelToken? _request;
  Timer? _debounce;
  List<Place> _items = [];
  bool _busy = true;
  String _error = '';
  int _total = 0, _offset = 0;
  Copy get c => widget.h5.copy;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant PlacePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query ||
        oldWidget.country != widget.country) {
      _request?.cancel();
      _debounce?.cancel();
      _error = '';
      _offset = 0;
      _items = [];
      _total = 0;
      _busy = true;
      _debounce = Timer(const Duration(milliseconds: 180), () => _load());
    }
  }

  Future<void> _load({bool more = false}) async {
    _request?.cancel();
    final token = CancelToken();
    _request = token;
    setState(() {
      _busy = true;
      _error = '';
      if (!more) {
        _offset = 0;
        _items = [];
      }
    });
    try {
      final result = await widget.h5.repository.cities(
        widget.country,
        widget.query,
        _offset,
        token,
      );
      if (!mounted || token.cancelled) return;
      final rows = objects(result['items']);
      final items = rows
          .map(Place.new)
          .where((place) => place.country == widget.country)
          .toList();
      await widget.h5.prepareText(
        items
            .map((place) => '${place.name(c.language)}${_detail(place)}')
            .join(),
      );
      if (!mounted || token.cancelled) return;
      setState(() {
        _items = more ? [..._items, ...items] : items;
        _offset += rows.length;
        _total = rows.isEmpty
            ? _offset
            : (result['total'] as num?)?.toInt() ?? _offset;
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
    _debounce?.cancel();
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
        if (_offset < _total)
          TextButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: Text(
              c.t('ui', 'morePlaces'),
              style: const TextStyle(fontSize: 11),
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
  String _detail(Place place) {
    final name = place.name(c.language);
    final local = text(
      place.json[switch (c.language) {
        'zh' => 'provinceNameChinese',
        'th' => 'provinceNameThai',
        _ => 'provinceNameEnglish',
      }],
    );
    final region = local.isNotEmpty
        ? local
        : text(place.json['provinceNameEnglish']);
    return [
      if (region.isNotEmpty && region != name) region,
      if (place.english.isNotEmpty &&
          place.english != name &&
          place.english != region)
        place.english,
    ].join(' · ');
  }

  Widget _option(Place place) {
    final detail = _detail(place);
    return InkWell(
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
            if (detail.isNotEmpty)
              Text(
                detail,
                style: const TextStyle(fontSize: 10, color: lavender),
              ),
          ],
        ),
      ),
    );
  }
}
