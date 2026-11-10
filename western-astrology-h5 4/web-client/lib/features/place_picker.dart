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
  final _countryText = TextEditingController(),
      _provinceText = TextEditingController(),
      _cityText = TextEditingController();
  String _country = '',
      _countryQuery = '',
      _provinceQuery = '',
      _cityQuery = '',
      _open = '',
      _language = '';
  Place? _province, _city;
  Copy get c => widget.h5.copy;
  @override
  void dispose() {
    _countryText.dispose();
    _provinceText.dispose();
    _cityText.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BirthplaceFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_language != c.language) {
      _language = c.language;
      if (_country.isNotEmpty) {
        _countryText.text = c.t(
          'jy',
          _country == 'global'
              ? 'globalCities'
              : _country == 'CN'
              ? 'china'
              : 'thailand',
        );
      }
      if (_province != null) _provinceText.text = _province!.name(c.language);
      if (_city != null) _cityText.text = _city!.name(c.language);
    }
  }

  void _clearCity() {
    _city = null;
    _cityQuery = '';
    _cityText.clear();
    widget.onSelected(null);
  }

  void _setCountry(String country) {
    setState(() {
      _country = country;
      _countryQuery = '';
      _province = null;
      _provinceQuery = '';
      _provinceText.clear();
      _clearCity();
      _open = '';
      _countryText.text = c.t(
        'jy',
        country == 'global'
            ? 'globalCities'
            : country == 'CN'
            ? 'china'
            : 'thailand',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _language = c.language;
    final hasRegions = _country == 'TH' || _country == 'CN';
    final canSearchCity = _country == 'global' || _province != null;
    Widget field(
      String id,
      String label,
      TextEditingController controller,
      String hint,
      VoidCallback open,
      ValueChanged<String> edit,
      Widget? options, {
      bool enabled = true,
    }) => Focus(
      onFocusChange: (focused) {
        // Web focus can arrive before an arrow press; only explicit taps open it.
        if (mounted && !focused && _open == id) {
          setState(() => _open = '');
        }
      },
      // Mouse-down on a suggestion must not blur and remove it before mouse-up.
      child: TextFieldTapRegion(
        onTapOutside: (_) {
          if (_open == id && mounted) setState(() => _open = '');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 46,
              child: TextFormField(
                key: ValueKey(id),
                controller: controller,
                enabled: enabled,
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
                    onPressed: enabled
                        ? () => setState(() => _open = _open == id ? '' : id)
                        : null,
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
            if (_open == id && enabled && options != null)
              Padding(padding: const EdgeInsets.only(top: 5), child: options),
          ],
        ),
      ),
    );
    final countries = [
      ('CN', c.t('jy', 'china'), 'china 中国 中國 จีน cn'),
      ('TH', c.t('jy', 'thailand'), 'thailand 泰国 泰國 ไทย th'),
      ('global', c.t('jy', 'globalCities'), 'world global 全球 ทั่วโลก'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field(
          'birth-country',
          '⌖  ${c.t('jy', 'country')}',
          _countryText,
          c.t('jy', 'countryPrompt'),
          () => setState(() => _open = 'birth-country'),
          (v) => setState(() {
            _countryQuery = v;
            _country = '';
            _province = null;
            _provinceQuery = '';
            _provinceText.clear();
            _clearCity();
            _open = 'birth-country';
          }),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF171027),
              border: Border.all(color: const Color(0x40E4BC78)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in countries)
                  if ('${item.$2} ${item.$3}'.toLowerCase().contains(
                    _countryQuery.toLowerCase().trim(),
                  ))
                    InkWell(
                      onTap: () => _setCountry(item.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.$2,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: field(
                'birth-province',
                c.t('jy', 'region'),
                _provinceText,
                c.t(
                  'jy',
                  !hasRegions
                      ? 'countryFirst'
                      : _country == 'TH'
                      ? 'thaiRegionPrompt'
                      : 'regionPrompt',
                ),
                () => setState(() => _open = 'birth-province'),
                (v) => setState(() {
                  _province = null;
                  _provinceQuery = v;
                  _clearCity();
                  _open = 'birth-province';
                }),
                PlacePicker(
                  key: ValueKey('province-$_country'),
                  h5: widget.h5,
                  country: _country,
                  query: _provinceQuery,
                  onSelected: (value) => setState(() {
                    _province = value;
                    _provinceText.text = value.name(c.language);
                    _provinceQuery = '';
                    _clearCity();
                    _open = '';
                  }),
                ),
                enabled: hasRegions,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: field(
                'birth-city',
                c.t('jy', 'city'),
                _cityText,
                c.t(
                  'jy',
                  canSearchCity
                      ? (_country == 'CN' ? 'cityExample' : 'citySearch')
                      : _country.isEmpty
                      ? 'countryFirst'
                      : 'regionFirst',
                ),
                () => setState(() => _open = 'birth-city'),
                (v) => setState(() {
                  _cityQuery = v;
                  _city = null;
                  widget.onSelected(null);
                  _open = 'birth-city';
                }),
                PlacePicker(
                  key: ValueKey('city-$_country-${_province?.id}'),
                  h5: widget.h5,
                  country: _country == 'global' ? '' : _country,
                  province: _province,
                  query: _cityQuery,
                  onSelected: (value) => setState(() {
                    _city = value;
                    _cityText.text = value.name(c.language);
                    _cityQuery = '';
                    _open = '';
                    widget.onSelected(value);
                  }),
                ),
                enabled: canSearchCity,
              ),
            ),
          ],
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
    required this.country,
    this.province,
    this.query = '',
    required this.onSelected,
    super.key,
  });
  final H5Controller h5;
  final String country;
  final Place? province;
  final String query;
  final ValueChanged<Place> onSelected;
  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  CancelToken? _request;
  Timer? _debounce;
  List<Place> _items = [];
  List<Place>? _provinces;
  bool _busy = true;
  String _query = '', _error = '';
  int _total = 0, _offset = 0;
  Copy get c => widget.h5.copy;
  @override
  void initState() {
    super.initState();
    _query = widget.query;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant PlacePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _query = widget.query;
      _request?.cancel();
      _debounce?.cancel();
      _error = '';
      _offset = 0;
      if (widget.province == null &&
          widget.country.isNotEmpty &&
          _provinces != null) {
        _items = _provinces!.where((p) => p.matches(_query)).toList();
        _total = _items.length;
        _busy = false;
        return;
      }
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
      List<Place> items;
      int total;
      if (widget.province == null && widget.country.isNotEmpty) {
        _provinces ??= await widget.h5.repository.provinces(
          widget.country,
          token,
        );
        items = _provinces!.where((p) => p.matches(_query)).toList();
        total = items.length;
      } else {
        final result = await widget.h5.repository.cities(
          widget.country,
          widget.province?.id ?? '',
          _query,
          _offset,
          token,
        );
        items = objects(result['items']).map(Place.new).toList();
        total = (result['total'] as num?)?.toInt() ?? items.length;
      }
      if (!mounted || token.cancelled) return;
      await widget.h5.prepareText(
        items.map((place) => place.name(c.language)).join(),
      );
      if (!mounted || token.cancelled) return;
      setState(() {
        _items = more ? [..._items, ...items] : items;
        _offset = _items.length;
        _total = total;
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
        if (widget.province != null && _query.trim().isEmpty)
          _option(widget.province!),
        for (final place in _items) _option(place),
        if (!_busy &&
            _items.isEmpty &&
            _error.isEmpty &&
            (widget.province == null || _query.trim().isNotEmpty))
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              c.t('ui', 'noCity'),
              style: const TextStyle(fontSize: 11, color: lavender),
            ),
          ),
        if (_items.length < _total)
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
          if (widget.province != null || widget.country.isEmpty)
            Text(
              place.english,
              style: const TextStyle(fontSize: 10, color: lavender),
            ),
        ],
      ),
    ),
  );
}
