import 'package:flutter/material.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/asset_tile.dart';
import '../../ui/theme.dart';
import '../home/live_page.dart' show objectsArtwork;

enum _ObjectCategory {
  all,
  fragrance,
  jewelry,
  journal,
  living;

  String title(AppLocalizations s) => switch (this) {
    all => s.allItems,
    fragrance => s.scentCategory,
    jewelry => s.jewelryCategory,
    journal => s.journalCategory,
    living => s.lifeCategory,
  };
}

enum _ShopObject {
  journal(390, _ObjectCategory.journal),
  candle(590, _ObjectCategory.fragrance),
  bracelet(490, _ObjectCategory.jewelry),
  diffuser(690, _ObjectCategory.living);

  const _ShopObject(this.price, this.category);
  final int price;
  final _ObjectCategory category;

  String title(AppLocalizations s) => switch (this) {
    journal => s.objectJournal,
    candle => s.objectCandle,
    bracelet => s.objectBracelet,
    diffuser => s.objectDiffuser,
  };

  String note(AppLocalizations s) => switch (this) {
    journal => s.objectJournalNote,
    candle => s.objectCandleNote,
    bracelet => s.objectBraceletNote,
    diffuser => s.objectDiffuserNote,
  };

  Widget get art =>
      AssetTile(objectsArtwork, column: index % 2, row: index ~/ 2, rows: 2);
}

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  _ObjectCategory _category = _ObjectCategory.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final items = _ShopObject.values
        .where(
          (item) =>
              (_category == _ObjectCategory.all ||
                  item.category == _category) &&
              '${item.title(s)} ${item.category.title(s)} ${item.note(s)} ${item.name}'
                  .toLowerCase()
                  .contains(_query),
        )
        .toList();
    return ListView(
      key: const PageStorageKey('objects-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FATE OBJECTS',
                    style: TextStyle(
                      color: goldColor,
                      fontSize: 9,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.storeTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 29,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    s.storeIntro,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton.outlined(
              onPressed: () => showShopOrders(context),
              tooltip: s.shopOrders,
              icon: const Icon(Icons.receipt_long_outlined, size: 21),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          textInputAction: TextInputAction.search,
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: s.storeSearch,
            prefixIcon: const Icon(Icons.search, size: 19),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final category in _ObjectCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      category.title(s),
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: _category == category,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 15),
        Text(
          s.sampleCatalog,
          style: const TextStyle(fontSize: 11, color: mutedColor),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          FateCard(child: Text(s.shopEmpty))
        else
          LayoutBuilder(
            builder: (context, box) => Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final item in items)
                  SizedBox(
                    width: (box.maxWidth - 12) / 2,
                    child: FateEntrance(
                      key: ValueKey(item),
                      child: _ObjectCard(item),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(s.shopDemoNotice, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ObjectCard extends StatelessWidget {
  const _ObjectCard(this.item);
  final _ShopObject item;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return FateCard(
      padding: EdgeInsets.zero,
      radius: 17,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _showObject(context, item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(aspectRatio: 1.12, child: item.art),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.note(s),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: mutedColor),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title(s),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 5,
                        children: [
                          Text(
                            '฿${item.price}',
                            style: const TextStyle(
                              fontSize: 22,
                              color: goldColor,
                            ),
                          ),
                          Text(
                            s.samplePrice,
                            style: const TextStyle(
                              fontSize: 9,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 2, 9, 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(37),
                padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
              ),
              onPressed: () => _add(context, item),
              child: Text(
                s.addToCart,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _add(BuildContext context, _ShopObject item) {
  final s = AppLocalizations.of(context);
  final cart = DependencyScope.of(context).demoCart;
  cart.value = {...cart.value, item.name: (cart.value[item.name] ?? 0) + 1};
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('${item.title(s)} · ${s.shopCart}'),
        duration: const Duration(seconds: 2),
      ),
    );
}

Future<void> _showObject(BuildContext context, _ShopObject item) {
  final s = AppLocalizations.of(context);
  return _shopSheet(
    context,
    item.title(s),
    (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(aspectRatio: 1.3, child: item.art),
        ),
        const SizedBox(height: 12),
        Text(item.note(s)),
        Text(
          '฿${item.price} · ${s.samplePrice}',
          style: const TextStyle(color: goldColor),
        ),
        const SizedBox(height: 10),
        Text(
          s.shopDemoNotice,
          style: const TextStyle(color: mutedColor, fontSize: 12),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            Navigator.pop(sheet);
            _add(context, item);
          },
          child: Text(s.addToCart),
        ),
      ],
    ),
  );
}

Future<void> showShopCart(BuildContext context) {
  final s = AppLocalizations.of(context);
  final cart = DependencyScope.of(context).demoCart;
  return _shopSheet(
    context,
    s.shopCart,
    (_) => ValueListenableBuilder(
      valueListenable: cart,
      builder: (context, items, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty) Text(s.cartEmpty),
          for (final item in _ShopObject.values)
            if ((items[item.name] ?? 0) > 0)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(dimension: 44, child: item.art),
                ),
                title: Text(item.title(s)),
                subtitle: Text('฿${item.price} × ${items[item.name]}'),
                trailing: IconButton(
                  tooltip: s.remove,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    final current = cart.value[item.name] ?? 0;
                    cart.value =
                        {...cart.value, if (current > 1) item.name: current - 1}
                          ..removeWhere(
                            (key, value) => key == item.name && current <= 1,
                          );
                  },
                ),
              ),
          const SizedBox(height: 12),
          Text(
            s.shopDemoNotice,
            style: const TextStyle(color: mutedColor, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

Future<void> showShopOrders(BuildContext context) {
  final s = AppLocalizations.of(context);
  return _shopSheet(
    context,
    s.shopOrders,
    (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.shopOrdersEmpty),
        const SizedBox(height: 6),
        Text(
          s.shopDemoNotice,
          style: const TextStyle(color: mutedColor, fontSize: 12),
        ),
      ],
    ),
  );
}

Future<void> _shopSheet(
  BuildContext context,
  String title,
  WidgetBuilder body,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 430),
  sheetAnimationStyle: FateMotion.dialog(context),
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: AppLocalizations.of(context).close,
              ),
            ],
          ),
          const SizedBox(height: 12),
          body(context),
        ],
      ),
    ),
  ),
);
