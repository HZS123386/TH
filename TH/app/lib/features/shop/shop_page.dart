import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/dependencies.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/asset_tile.dart';
import '../../ui/theme.dart';

const objectsArtwork = 'assets/images/live-shop-objects.webp';

String _baht(AppLocalizations s, int amount) => NumberFormat.currency(
  locale: s.localeName,
  symbol: '฿',
  decimalDigits: 0,
).format(amount);

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
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final query = _search.text.trim().toLowerCase();
    final items = _ShopObject.values
        .where(
          (item) =>
              (_category == _ObjectCategory.all ||
                  item.category == _category) &&
              '${item.title(s)} ${item.category.title(s)} ${item.note(s)} ${item.name}'
                  .toLowerCase()
                  .contains(query),
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
          controller: _search,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: s.storeSearch,
            prefixIcon: const Icon(Icons.search, size: 19),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: s.clearSearch,
                    onPressed: () => setState(_search.clear),
                    icon: const Icon(Icons.close_rounded),
                  ),
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
                    onSelected: (_) {
                      if (category == _category) return;
                      FateMotion.selectionFeedback();
                      setState(() => _category = category);
                    },
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
          FateCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.shopEmpty),
                TextButton.icon(
                  icon: const Icon(Icons.clear_all),
                  label: Text(s.allItems),
                  onPressed: () => setState(() {
                    _search.clear();
                    _category = _ObjectCategory.all;
                  }),
                ),
              ],
            ),
          )
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
                        item.title(s),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.note(s),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: mutedColor),
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 5,
                        children: [
                          Text(
                            _baht(s, item.price),
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

class LiveShopProduct extends StatelessWidget {
  const LiveShopProduct.journal({super.key}) : _item = _ShopObject.journal;
  const LiveShopProduct.candle({super.key}) : _item = _ShopObject.candle;

  final _ShopObject _item;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return FateCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox.square(dimension: 48, child: _item.art),
        ),
        title: Text(_item.title(s)),
        subtitle: Text(
          '${_baht(s, _item.price)} · ${s.samplePrice}',
          style: const TextStyle(color: goldColor),
        ),
        trailing: const Icon(Icons.chevron_right, color: goldColor),
        onTap: () => _showObject(context, _item),
      ),
    );
  }
}

void _changeQuantity(
  ValueNotifier<Map<String, int>> cart,
  _ShopObject item,
  int delta,
) {
  final items = {...cart.value};
  final quantity = (items[item.name] ?? 0) + delta;
  if (quantity <= 0) {
    items.remove(item.name);
  } else {
    items[item.name] = quantity;
  }
  cart.value = Map.unmodifiable(items);
}

void _add(BuildContext context, _ShopObject item) {
  final s = AppLocalizations.of(context);
  final cart = DependencyScope.of(context).demoCart;
  _changeQuantity(cart, item, 1);
  FateMotion.selectionFeedback();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('${item.title(s)} · ${s.shopCart}'),
        duration: const Duration(seconds: 2),
      ),
    );
}

Future<void> _showObject(BuildContext context, _ShopObject item) async {
  final s = AppLocalizations.of(context);
  final cart = DependencyScope.of(context).demoCart;
  var viewCart = false;
  await _shopSheet(
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
          '${_baht(s, item.price)} · ${s.samplePrice}',
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
        if (cart.value.isNotEmpty)
          TextButton.icon(
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(s.shopCart),
            onPressed: () {
              viewCart = true;
              Navigator.pop(sheet);
            },
          ),
      ],
    ),
  );
  if (context.mounted && viewCart) await showShopCart(context);
}

int _shopTotal(Map<String, int> items) => _ShopObject.values.fold(
  0,
  (total, item) => total + item.price * (items[item.name] ?? 0),
);

Future<void> showShopCart(BuildContext context) async {
  final s = AppLocalizations.of(context);
  final dependencies = DependencyScope.of(context);
  final cart = dependencies.demoCart;
  final orders = dependencies.demoShopOrders;
  var review = false;
  int? orderNumber;
  var openOrders = false;
  await _shopSheet(
    context,
    s.shopCart,
    (sheet) => StatefulBuilder(
      builder: (context, setState) => ValueListenableBuilder(
        valueListenable: cart,
        builder: (context, items, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (orderNumber != null) ...[
              const Icon(
                Icons.check_circle_outline,
                color: goldColor,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                s.shopOrderPlaced,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${s.shopOrderNumber} #$orderNumber',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  openOrders = true;
                  Navigator.pop(sheet);
                },
                child: Text(s.shopOrders),
              ),
            ] else if (items.isEmpty) ...[
              Text(s.cartEmpty),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(sheet),
                child: Text(s.close),
              ),
            ] else ...[
              if (review) ...[
                Text(
                  s.shopReviewOrder,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  s.shopDemoNotice,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              for (final item in _ShopObject.values)
                if (items[item.name] case final int quantity)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox.square(
                            dimension: 44,
                            child: item.art,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title(s)),
                              Text(
                                '${_baht(s, item.price)} × $quantity',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (!review) ...[
                          IconButton(
                            tooltip: s.remove,
                            onPressed: () => _changeQuantity(cart, item, -1),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          IconButton(
                            tooltip: s.shopIncreaseQuantity,
                            onPressed: () => _changeQuantity(cart, item, 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ],
                    ),
                  ),
              const Divider(height: 24),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                children: [
                  Text(s.shopSubtotal),
                  Text(
                    _baht(s, _shopTotal(items)),
                    style: const TextStyle(
                      color: goldColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: review
                    ? () {
                        if (cart.value.isEmpty || orderNumber != null) return;
                        orders.value = [...orders.value, cart.value];
                        setState(() => orderNumber = orders.value.length);
                        cart.value = const {};
                      }
                    : () => setState(() => review = true),
                child: Text(review ? s.shopPlaceDemoOrder : s.shopReviewOrder),
              ),
              if (review)
                TextButton(
                  onPressed: () => setState(() => review = false),
                  child: Text(s.shopCart),
                ),
            ],
          ],
        ),
      ),
    ),
  );
  if (context.mounted && openOrders) await showShopOrders(context);
}

Future<void> showShopOrders(BuildContext context) {
  final s = AppLocalizations.of(context);
  final orders = DependencyScope.of(context).demoShopOrders.value;
  return _shopSheet(
    context,
    s.shopOrders,
    (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (orders.isEmpty) Text(s.shopOrdersEmpty),
        for (final (index, items) in orders.indexed.toList().reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FateCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.shopOrderNumber} #${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  for (final item in _ShopObject.values)
                    if (items[item.name] case final int quantity)
                      Text(
                        '${item.title(s)} × $quantity',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  Text(
                    _baht(s, _shopTotal(items)),
                    style: const TextStyle(color: goldColor),
                  ),
                ],
              ),
            ),
          ),
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
