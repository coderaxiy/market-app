import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_error.dart';
import '../../../core/format.dart';
import '../../../core/routing/paths.dart';
import '../../../core/settings/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../cart/application/cart_controller.dart';
import '../../cart/data/cart.dart';
import '../../logistics/application/pickup_providers.dart';
import '../../logistics/data/pickup_point.dart';
import '../../logistics/presentation/pickup_point_picker.dart';
import '../data/checkout.dart';
import '../data/checkout_repository.dart';

const _namePrefsKey = 'checkout.recipient.name';
const _phonePrefsKey = 'checkout.recipient.phone';
const _phonePrefix = '+998 ';

/// Phone digits the storefront accepts (`+998 90 123-45-67` is 12).
bool isPlausiblePhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '').length;
  return digits >= 9 && digits <= 15;
}

/// `/checkout` (login required): pickup point, recipient, payment, then place the order.
/// Only cash at the pickup point is open: online gateways aren't connected yet.
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  final _notes = TextEditingController();
  PickupPointRead? _chosen;
  List<PriceChange>? _priceChanges;
  String? _nameKey;
  String? _phoneKey;
  var _pointMissing = false;
  String? _serverError;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final user = ref.read(sessionProvider).value;
    _name = TextEditingController(
      text: prefs.getString(_namePrefsKey) ?? user?.fullName ?? '',
    );
    _phone = TextEditingController(
      text: prefs.getString(_phonePrefsKey) ?? user?.phone ?? _phonePrefix,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  PickupPointRead? get _point =>
      _chosen ?? ref.read(lastUsedPickupPointProvider).value;

  Future<void> _choosePoint() async {
    final picked = await showPickupPointPicker(context, selectedId: _point?.id);
    if (picked != null && mounted) {
      setState(() {
        _chosen = picked;
        _pointMissing = false;
      });
    }
  }

  Future<void> _place({bool acceptPrices = false}) async {
    final t = ref.read(tProvider);
    final point = _point;
    setState(() {
      _nameKey = _name.text.trim().isEmpty ? 'checkout.nameRequired' : null;
      _phoneKey = isPlausiblePhone(_phone.text)
          ? null
          : 'checkout.phoneInvalid';
      _pointMissing = point == null;
      _serverError = null;
    });
    if (_nameKey != null || _phoneKey != null || point == null) return;

    setState(() => _busy = true);
    final cart = ref.read(cartProvider.notifier);
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      // The buyer accepted the new prices: re-save each affected line, then place.
      if (acceptPrices) await cart.acceptPriceChanges();
      final response = await ref
          .read(checkoutRepositoryProvider)
          .checkout(
            recipient: Recipient(
              fullName: _name.text,
              phone: _phone.text,
              notes: _notes.text,
            ),
            pickupPointId: point.id,
            paymentMethod: PaymentMethod.cashOnDelivery,
          );
      await prefs.setString(_namePrefsKey, _name.text.trim());
      await prefs.setString(_phonePrefsKey, _phone.text.trim());
      // The cart was turned into the order: reload it (an empty one), best effort.
      try {
        await cart.refresh();
      } catch (_) {}
      if (!mounted) return;
      context.go('${Paths.order(response.orderId)}?placed=1');
    } on PriceChangedException catch (changes) {
      // Show old vs new; the cart behind it reloads with the current prices.
      try {
        await cart.refresh();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _busy = false;
        _priceChanges = changes.items;
      });
    } catch (error) {
      if (!mounted) return;
      // String details ("This pickup point isn't available - choose another one") are
      // safe to show; anything else gets the generic message.
      setState(() {
        _busy = false;
        _serverError = apiErrorMessage(error, t('checkout.placeFailed'));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final intl = ref.watch(settingsProvider.select((s) => s.locale.intlTag));
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final cart = ref.watch(cartProvider);
    final lastUsed = ref.watch(lastUsedPickupPointProvider);
    final point = _chosen ?? lastUsed.value;

    return Scaffold(
      appBar: AppBar(title: Text(t('checkout.title'))),
      body: cart.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: apiErrorMessage(error, t('state.loadFailed')),
          onRetry: () => ref.invalidate(cartProvider),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return EmptyState(
              message: t('checkout.emptyBody'),
              action: FilledButton(
                onPressed: () => context.go(Paths.catalog),
                style: FilledButton.styleFrom(minimumSize: const Size(200, 44)),
                child: Text(t('home.heroCta')),
              ),
            );
          }
          final blocked =
              data.hasUnavailableItems ||
              data.items.any((item) => item.available && !item.inStock);
          final changed = data.priceChangedItems;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_serverError != null) FormErrorBanner(_serverError!),
                    // --- Pickup point ---
                    Text(t('checkout.pickupPoint'), style: text.titleMedium),
                    const SizedBox(height: 8),
                    if (point == null && lastUsed.isLoading && _chosen == null)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: LoadingState(),
                      )
                    else if (point == null)
                      OutlinedButton.icon(
                        onPressed: _choosePoint,
                        icon: const Icon(Icons.place_outlined),
                        label: Text(t('checkout.choosePoint')),
                      )
                    else ...[
                      PointTile(
                        point: point,
                        selected: true,
                        onTap: _choosePoint,
                        trailing: TextButton(
                          onPressed: _choosePoint,
                          child: Text(t('checkout.change')),
                        ),
                      ),
                      if (_chosen == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            t('checkout.lastUsedNote'),
                            style: text.bodySmall?.copyWith(
                              color: colors.mutedForeground,
                            ),
                          ),
                        ),
                    ],
                    if (_pointMissing)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          t('checkout.pointRequired'),
                          style: TextStyle(color: colors.destructive),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        t('checkout.onePointNote'),
                        style: text.bodySmall?.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                    // --- Recipient ---
                    const SizedBox(height: 24),
                    Text(t('checkout.recipient'), style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      t('checkout.recipientHint'),
                      style: text.bodySmall?.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: InputDecoration(
                        labelText: t('checkout.fullName'),
                        errorText: _nameKey == null ? null : t(_nameKey!),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: InputDecoration(
                        labelText: t('checkout.phone'),
                        errorText: _phoneKey == null ? null : t(_phoneKey!),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: t('checkout.notes'),
                        helperText: t('checkout.notesHint'),
                      ),
                    ),
                    // --- Payment ---
                    const SizedBox(height: 24),
                    Text(t('checkout.payment'), style: text.titleMedium),
                    const SizedBox(height: 8),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colors.accent, width: 2),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.check_circle, color: colors.accent),
                        title: Text(t('checkout.cashAtPoint')),
                        subtitle: Text(t('checkout.cashAtPointHint')),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        t('checkout.onlineSoon'),
                        style: text.bodySmall?.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                    // --- Items and totals ---
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          t('checkout.items', {'count': data.itemCount}),
                          style: text.titleMedium,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.go(Paths.cart),
                          child: Text(t('checkout.editCart')),
                        ),
                      ],
                    ),
                    if (blocked)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          t('checkout.fixCart'),
                          style: TextStyle(color: colors.destructive),
                        ),
                      ),
                    if (_priceChanges != null || changed.isNotEmpty)
                      _PriceChanges(
                        changes: _priceChanges ?? const [],
                        cart: data,
                        intl: intl,
                      ),
                  ],
                ),
              ),
              _PlaceBar(
                total: formatMoney(data.subtotal, intl),
                busy: _busy,
                blocked: blocked,
                acceptPrices: _priceChanges != null || changed.isNotEmpty,
                onPlace: _place,
                onAcceptAndPlace: () => _place(acceptPrices: true),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Old vs new price for each line that moved, named by product.
class _PriceChanges extends ConsumerWidget {
  const _PriceChanges({
    required this.changes,
    required this.cart,
    required this.intl,
  });

  final List<PriceChange> changes;
  final CartRead cart;
  final String intl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final colors = AppColors.of(context);
    // Prefer what the server reported; fall back to the cart's own old/new prices.
    final rows = changes.isNotEmpty
        ? [
            for (final change in changes)
              (
                title: _titleFor(change),
                old: change.oldPrice,
                price: change.newPrice,
              ),
          ]
        : [
            for (final item in cart.priceChangedItems)
              (
                title: item.product.title,
                old: item.priceSnapshot,
                price: item.unitPrice,
              ),
          ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('checkout.pricesChanged'),
            style: TextStyle(color: colors.warning),
          ),
          for (final row in rows)
            Text(
              '${row.title}: ${t('cart.priceChanged', {'old': formatMoney(row.old, intl), 'price': formatMoney(row.price, intl)})}',
            ),
        ],
      ),
    );
  }

  String _titleFor(PriceChange change) {
    for (final item in cart.items) {
      if (item.product.id == change.productId &&
          item.variant?.id == change.variantId) {
        return item.product.title;
      }
    }
    return '#${change.productId}';
  }
}

class _PlaceBar extends ConsumerWidget {
  const _PlaceBar({
    required this.total,
    required this.busy,
    required this.blocked,
    required this.acceptPrices,
    required this.onPlace,
    required this.onAcceptAndPlace,
  });

  final String total;
  final bool busy;
  final bool blocked;
  final bool acceptPrices;
  final VoidCallback onPlace;
  final VoidCallback onAcceptAndPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(t('checkout.toPay'), style: text.titleSmall),
                const Spacer(),
                Text(
                  total,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            Text(
              t('checkout.inspectNote'),
              style: text.bodySmall?.copyWith(color: colors.mutedForeground),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy || blocked
                    ? null
                    : (acceptPrices ? onAcceptAndPlace : onPlace),
                child: Text(
                  busy
                      ? t('checkout.placing')
                      : acceptPrices
                      ? t('checkout.acceptAndPlace')
                      : t('checkout.placeOrder'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
