import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../app/controller.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../ui/theme.dart';

Future<String?> chooseCountry(BuildContext context, H5Controller h5) =>
    showDialog<String>(
      context: context,
      builder: (context) => _CountryDialog(copy: h5.copy),
    );

class _CountryDialog extends StatefulWidget {
  const _CountryDialog({required this.copy});
  final Copy copy;
  @override
  State<_CountryDialog> createState() => _CountryDialogState();
}

class _CountryDialogState extends State<_CountryDialog> {
  String query = '';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.copy.t('ui', 'country')),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.copy.t('ui', 'countryPlaceholder'),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v.toLowerCase().trim()),
          ),
          const SizedBox(height: 12),
          for (final code in ['TH', 'CN'])
            if ('${code == 'TH' ? 'thailand ไทย ประเทศไทย 泰国' : 'china 中国 จีน'} $code'
                .toLowerCase()
                .contains(query))
              ListTile(
                title: Text(widget.copy.t('ui', 'countryNames.$code')),
                onTap: () => Navigator.pop(context, code),
              ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.copy.t('ui', 'close')),
      ),
    ],
  );
}

Future<Place?> choosePlace(
  BuildContext context,
  H5Controller h5,
  String country, {
  Place? province,
}) => showDialog<Place>(
  context: context,
  builder: (context) =>
      PlacePicker(h5: h5, country: country, province: province),
);

class PlacePicker extends StatefulWidget {
  const PlacePicker({
    required this.h5,
    required this.country,
    this.province,
    super.key,
  });
  final H5Controller h5;
  final String country;
  final Place? province;
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
    unawaited(_load());
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
      if (widget.province == null) {
        _provinces ??= await widget.h5.repository.provinces(
          widget.country,
          token,
        );
        items = _provinces!.where((p) => p.matches(_query)).toList();
        total = items.length;
      } else {
        final result = await widget.h5.repository.cities(
          widget.country,
          widget.province!.id,
          _query,
          _offset,
          token,
        );
        items = objects(result['items']).map(Place.new).toList();
        total = (result['total'] as num?)?.toInt() ?? items.length;
      }
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
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 430,
        maxHeight: max(
          200,
          min(
            590,
            MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom -
                80,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.t('ui', widget.province == null ? 'province' : 'city'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: c.t('ui', 'close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: c.t(
                  'ui',
                  widget.province == null
                      ? widget.country == 'TH'
                            ? 'thaiProvincePlaceholder'
                            : 'provincePlaceholder'
                      : widget.country == 'TH'
                      ? 'thaiCityPlaceholder'
                      : 'cityPlaceholder',
                ),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) {
                _query = value;
                _request?.cancel();
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => _load(),
                );
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _busy && _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 14),
                          Text(c.t('ui', 'searching')),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        if (widget.province != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.location_city_outlined,
                              color: gold,
                            ),
                            title: Text(widget.province!.label(c.language)),
                            subtitle: Text(
                              c.t('ui', 'provinceNote'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onTap: () =>
                                Navigator.pop(context, widget.province),
                          ),
                        for (final place in _items)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text(place.label(c.language)),
                            subtitle: Text(
                              place.english,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: gold,
                            ),
                            onTap: () => Navigator.pop(context, place),
                          ),
                        if (!_busy && _items.isEmpty && _error.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(c.t('ui', 'noCity')),
                          ),
                        if (_items.length < _total)
                          TextButton(
                            onPressed: _busy ? null : () => _load(more: true),
                            child: _busy
                                ? const CircularProgressIndicator()
                                : Text(c.t('ui', 'morePlaces')),
                          ),
                        errorMessage(_error),
                        if (_error.isNotEmpty)
                          TextButton(
                            onPressed: () => _load(),
                            child: Text(c.t('ui', 'retryPlaces')),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
