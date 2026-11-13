import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/birth_profile.dart';
import '../../data/profile_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme.dart';

/// The landing-page interaction: searchable country, region and city fields.
class BirthplaceFields extends StatefulWidget {
  const BirthplaceFields({
    required this.repository,
    required this.onSelected,
    this.initialProfile,
    this.enabled = true,
    super.key,
  });
  final ProfileRepository repository;
  final BirthProfile? initialProfile;
  final ValueChanged<Map<String, dynamic>?> onSelected;
  final bool enabled;
  @override
  State<BirthplaceFields> createState() => _BirthplaceFieldsState();
}

class _BirthplaceFieldsState extends State<BirthplaceFields> {
  final _countryText = TextEditingController(),
      _regionText = TextEditingController(),
      _cityText = TextEditingController();
  final _menus = {
    for (final id in ['country', 'region', 'city'])
      id: OverlayPortalController(),
  };
  final Map<String, List<Map<String, dynamic>>> _regions = {};
  String _country = '',
      _countryQuery = '',
      _query = '',
      _open = '',
      _language = '';
  Map<String, dynamic>? _region, _city;
  List<Map<String, dynamic>> _rows = [];
  bool _busy = false, _failed = false;
  int _generation = 0, _total = 0;
  Timer? _debounce;
  AppLocalizations get s => AppLocalizations.of(context);
  bool get _hasRegions => ['CN', 'TH'].contains(_country);
  bool get _canChooseCity =>
      _country.isNotEmpty && (!_hasRegions || _region != null);

  String _name(Map<String, dynamic> row) {
    final key = _language == 'zh'
        ? 'nameChinese'
        : _language == 'th'
        ? 'nameThai'
        : 'nameEnglish';
    final value = row[key];
    return value is String && value.isNotEmpty
        ? value
        : (row['nameEnglish'] as String? ?? '');
  }

  Map<String, String> get _countries => {
    'CN': s.countryCN,
    'TH': s.countryTH,
    'VN': s.countryVN,
    'US': s.countryUS,
  };
  bool _matches(Map<String, dynamic> row, String query) =>
      [
        row['nameEnglish'],
        row['nameChinese'],
        row['nameThai'],
        ...row['aliases'] as List? ?? [],
      ].whereType<String>().any(
        (v) => v.toLowerCase().contains(query.toLowerCase().trim()),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_restore());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = s.localeName.split('_').first;
    if (_language == language) return;
    _language = language;
    _countryText.text = _countries[_country] ?? '';
    if (_region != null) _regionText.text = _name(_region!);
    if (_city != null) _cityText.text = _name(_city!);
  }

  Future<void> _restore() async {
    final profile = widget.initialProfile;
    if (profile?.placeId == null) return;
    final generation = ++_generation;
    Map<String, dynamic>? city;
    try {
      if (['VN', 'US'].contains(profile!.countryCode) &&
          profile.latitude != null &&
          profile.longitude != null) {
        city = {
          'id': profile.placeId,
          'countryCode': profile.countryCode,
          'nameEnglish': profile.place.split(',').first,
          'timeZone': profile.timezone,
          'latitude': profile.latitude,
          'longitude': profile.longitude,
        };
      } else {
        final result = await widget.repository.locations(
          profile.placeId!,
          _language,
          country: profile.countryCode ?? '',
          level: 'detail',
        );
        city = result.items.firstOrNull;
      }
      if (!mounted || generation != _generation || city == null) return;
      if (!_countries.containsKey(city['countryCode'])) return;
      final restored = city;
      setState(() {
        _country = restored['countryCode'] as String;
        _countryText.text = _countries[_country]!;
        if (_hasRegions) {
          _region = {
            ...restored,
            'id': restored['provinceId'] ?? restored['id'],
            'nameEnglish':
                restored['provinceNameEnglish'] ?? restored['nameEnglish'],
            'nameChinese':
                restored['provinceNameChinese'] ?? restored['nameChinese'],
            'nameThai': restored['provinceNameThai'] ?? restored['nameThai'],
          };
          _regionText.text = _name(_region!);
        }
        _city = restored;
        _cityText.text = _name(restored);
      });
      widget.onSelected(city);
    } catch (_) {
      // Keep the form editable when a saved directory entry cannot be restored.
    }
  }

  void _close() {
    _menus[_open]?.hide();
    _open = '';
  }

  void _resetQuery() {
    ++_generation;
    _debounce?.cancel();
    _rows = [];
    _total = 0;
    _query = '';
    _busy = false;
    _failed = false;
  }

  void _clearCity() {
    _city = null;
    _cityText.clear();
    widget.onSelected(null);
  }

  void _chooseCountry(String value) {
    setState(() {
      _resetQuery();
      _close();
      _country = value;
      _countryQuery = '';
      _countryText.text = _countries[value]!;
      _region = null;
      _regionText.clear();
      _clearCity();
    });
  }

  void _openMenu(String id) {
    if (!widget.enabled || _open == id) return;
    setState(() {
      _resetQuery();
      _close();
      _open = id;
      _menus[id]!.show();
      _countryQuery = '';
    });
    if (id != 'country') unawaited(_load());
  }

  void _edit(String id, String value) {
    setState(() {
      _resetQuery();
      if (_open != id) {
        _close();
        _open = id;
        _menus[id]!.show();
      }
      if (id == 'country') {
        _countryQuery = value;
        _country = '';
        _region = null;
        _regionText.clear();
        _clearCity();
      } else {
        _query = value;
        if (id == 'region') {
          _region = null;
          _clearCity();
        } else {
          _city = null;
          widget.onSelected(null);
        }
        _busy = true;
      }
    });
    if (id != 'country') {
      _debounce = Timer(const Duration(milliseconds: 180), () => _load());
    }
  }

  Future<void> _load({bool more = false}) async {
    final id = _open, generation = ++_generation;
    if (!['region', 'city'].contains(id)) return;
    final query = _query;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      List<Map<String, dynamic>> rows;
      int total;
      if (id == 'region') {
        final available =
            _regions[_country] ??
            (await widget.repository.locations(
              '',
              _language,
              country: _country,
              level: 'province',
            )).items;
        if (!mounted || generation != _generation) return;
        _regions[_country] = available;
        rows = available.where((row) => _matches(row, query)).toList();
        total = rows.length;
      } else {
        final result = await widget.repository.locations(
          query,
          _language,
          country: _country,
          level: _hasRegions ? 'locality' : 'city',
          province: _region?['id'] as String? ?? '',
          offset: more ? _rows.length : 0,
        );
        rows = result.items;
        total = result.total;
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _rows = more ? [..._rows, ...rows] : rows;
        _total = total;
        _busy = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _failed = true;
          _busy = false;
        });
      }
    }
  }

  void _choose(Map<String, dynamic> row) {
    if (_open == 'region') {
      setState(() {
        _resetQuery();
        _close();
        _region = row;
        _regionText.text = _name(row);
        _clearCity();
      });
      return;
    }
    final zone = row['timeZone'] ?? row['timezone'];
    if (zone is! String ||
        zone.isEmpty ||
        row['latitude'] is! num ||
        row['longitude'] is! num) {
      return;
    }
    setState(() {
      _resetQuery();
      _close();
      _city = row;
      _cityText.text = _name(row);
    });
    widget.onSelected(row);
  }

  Widget _options(String id) => Material(
    color: panelColor,
    elevation: 8,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: Container(
      decoration: BoxDecoration(border: Border.all(color: lineColor)),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          if (id == 'country') ...[
            for (final country in _countries.entries)
              if ('${country.value} ${country.key} ${{'CN': 'China 中国 中國 จีน Trung Quốc', 'TH': 'Thailand 泰国 泰國 ไทย Thái Lan', 'VN': 'Vietnam 越南 เวียดนาม Việt Nam', 'US': 'USA United States 美国 美國 สหรัฐอเมริกา Hoa Kỳ'}[country.key]}'
                  .toLowerCase()
                  .contains(_countryQuery.toLowerCase().trim()))
                ListTile(
                  dense: true,
                  title: Text(country.value),
                  onTap: () => _chooseCountry(country.key),
                ),
          ] else ...[
            if (_busy && _rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            if (id == 'city' &&
                _region != null &&
                _query.isEmpty &&
                !_rows.any((row) => row['id'] == _region!['id']))
              ListTile(
                dense: true,
                title: Text(_name(_region!)),
                onTap: () => _choose(_region!),
              ),
            for (final row in _rows)
              ListTile(
                dense: true,
                title: Text(_name(row), style: const TextStyle(fontSize: 13)),
                onTap: () => _choose(row),
              ),
            if (!_busy && !_failed && _rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  s.noCityResults,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (_rows.length < _total)
              TextButton(
                onPressed: _busy ? null : () => _load(more: true),
                child: Text(s.moreLocations),
              ),
            if (_failed) TextButton(onPressed: _load, child: Text(s.retry)),
          ],
        ],
      ),
    ),
  );
  Widget _floating(
    BuildContext context,
    OverlayChildLayoutInfo layout,
    String id,
  ) {
    if (_open != id) return const SizedBox.shrink();
    final anchor = MatrixUtils.transformRect(
      layout.childPaintTransform,
      Offset.zero & layout.childSize,
    );
    final view = MediaQueryData.fromView(View.of(context));
    final top = view.padding.top + 8;
    final bottom =
        (view.size.height - view.viewInsets.bottom).clamp(
          0.0,
          layout.overlaySize.height,
        ) -
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
      width: anchor.width,
      top: upward ? null : anchor.bottom + 5,
      bottom: upward ? layout.overlaySize.height - anchor.top + 5 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: upward ? above : below),
        child: TextFieldTapRegion(child: _options(id)),
      ),
    );
  }

  Widget _field(
    String id,
    String label,
    TextEditingController controller,
    String hint, {
    bool enabled = true,
  }) => Focus(
    onFocusChange: (focused) {
      if (!focused && mounted && _open == id) setState(_close);
    },
    child: TextFieldTapRegion(
      onTapOutside: (_) {
        if (mounted && _open == id) setState(_close);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          OverlayPortal.overlayChildLayoutBuilder(
            controller: _menus[id]!,
            overlayChildBuilder: (context, layout) =>
                _floating(context, layout, id),
            child: TextFormField(
              key: ValueKey('birth-$id'),
              controller: controller,
              enabled: widget.enabled && enabled,
              autocorrect: false,
              maxLength: 80,
              style: const TextStyle(fontSize: 13),
              onTap: () => _openMenu(id),
              onChanged: (v) => _edit(id, v),
              validator: (_) =>
                  id == 'city' && _city == null ? s.selectBirthCity : null,
              decoration: InputDecoration(
                hintText: hint,
                counterText: '',
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 30,
                  maxWidth: 30,
                ),
                suffixIcon: IconButton(
                  tooltip: label,
                  onPressed: widget.enabled && enabled
                      ? () {
                          if (_open == id) {
                            setState(_close);
                          } else {
                            _openMenu(id);
                          }
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: goldColor,
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _field('country', s.country, _countryText, s.selectCountry),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _field(
              'region',
              s.birthRegion,
              _regionText,
              _country.isEmpty
                  ? s.countryFirst
                  : _hasRegions
                  ? s.selectRegion
                  : s.regionNotNeeded,
              enabled: _hasRegions,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _field(
              'city',
              s.birthplace,
              _cityText,
              _country.isEmpty
                  ? s.countryFirst
                  : _canChooseCity
                  ? s.searchBirthCity
                  : s.regionFirst,
              enabled: _canChooseCity,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(s.birthLocationHint, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
  @override
  void dispose() {
    ++_generation;
    _debounce?.cancel();
    _countryText.dispose();
    _regionText.dispose();
    _cityText.dispose();
    super.dispose();
  }
}
