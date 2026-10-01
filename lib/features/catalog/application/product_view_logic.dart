// Pure logic of the product page, ported from the storefront's `ProductView.tsx` and
// `[product].astro`: variant axes, picking a variant, option states, photo order, specs.

import '../../../core/format.dart';
import '../../../core/i18n/i18n.dart';
import '../data/category.dart';
import '../data/product.dart';

/// A variant-defining attribute with its values as strings (as shown and compared).
class VariantAxis {
  const VariantAxis({
    required this.key,
    required this.label,
    required this.options,
  });

  final String key;
  final String label;
  final List<String> options;
}

/// A spec row, localized and formatted.
class SpecRow {
  const SpecRow(this.label, this.value);

  final String label;
  final String value;
}

/// Axis key -> chosen value.
typedef Selection = Map<String, String>;

String valueOf(ProductPublicVariantRead variant, String key) =>
    '${variant.attributes[key] ?? ''}';

Selection selectionOf(
  ProductPublicVariantRead? variant,
  List<VariantAxis> axes,
) => variant == null
    ? {}
    : {for (final axis in axes) axis.key: valueOf(variant, axis.key)};

/// The selection a page opens with: the first variant that is in stock, else the first.
Selection initialSelection(ProductPublicRead product, List<VariantAxis> axes) {
  if (product.variants.isEmpty) return {};
  final first = product.variants.firstWhere(
    (variant) => variant.inStock,
    orElse: () => product.variants.first,
  );
  return selectionOf(first, axes);
}

ProductPublicVariantRead? findVariant(
  List<ProductPublicVariantRead> variants,
  Selection selection,
  List<VariantAxis> axes,
) {
  for (final variant in variants) {
    if (axes.every(
      (axis) => valueOf(variant, axis.key) == selection[axis.key],
    )) {
      return variant;
    }
  }
  return null;
}

/// The variant axes, labelled and ordered from the category's attribute definitions (raw
/// keys without them). [categoryAttributes] come from `GET /categories/{id}/attributes`.
List<VariantAxis> buildAxes(
  ProductPublicRead product,
  List<CategoryAttributePublicRead> categoryAttributes,
  AppLocale locale,
) {
  final keys = <String>{
    for (final variant in product.variants) ...variant.attributes.keys,
  }.toList();
  final byKey = {for (final a in categoryAttributes) a.key: a};
  int rank(String key) => byKey[key]?.sortOrder ?? 1 << 30;
  keys.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : a.compareTo(b);
  });
  return [
    for (final key in keys)
      () {
        final attribute = byKey[key];
        final values = <String>{
          for (final variant in product.variants) valueOf(variant, key),
        }.where((value) => value.isNotEmpty).toList();
        final order = attribute?.options ?? const <String>[];
        int position(String value) {
          final index = order.indexOf(value);
          return index >= 0 ? index : order.length;
        }

        values.sort((a, b) => position(a).compareTo(position(b)));
        final label = attribute == null
            ? key
            : pickTranslation(
                    attribute.translations,
                    (t) => t.locale,
                    locale,
                  )?.label ??
                  key;
        return VariantAxis(
          key: key,
          label: attribute?.unit == null ? label : '$label, ${attribute!.unit}',
          options: values,
        );
      }(),
  ];
}

/// Choosing [value] on [key]. If no variant has that exact combination, jump to one that
/// has [value] (preferring one in stock).
Selection choose(
  Selection current,
  String key,
  String value,
  List<ProductPublicVariantRead> variants,
  List<VariantAxis> axes,
) {
  final next = {...current, key: value};
  if (findVariant(variants, next, axes) != null) return next;
  final candidates = [
    for (final variant in variants)
      if (valueOf(variant, key) == value) variant,
  ];
  if (candidates.isEmpty) return current;
  return selectionOf(
    candidates.firstWhere((v) => v.inStock, orElse: () => candidates.first),
    axes,
  );
}

enum OptionState {
  available,
  soldOut,

  /// Exists only together with a different choice on another axis.
  other,
}

OptionState optionState(
  String key,
  String value,
  Selection selection,
  List<ProductPublicVariantRead> variants,
  List<VariantAxis> axes,
) {
  final matches = [
    for (final variant in variants)
      if (valueOf(variant, key) == value &&
          axes.every(
            (axis) =>
                axis.key == key ||
                valueOf(variant, axis.key) == selection[axis.key],
          ))
        variant,
  ];
  if (matches.isEmpty) return OptionState.other;
  return matches.any((v) => v.inStock)
      ? OptionState.available
      : OptionState.soldOut;
}

/// The chosen variant's own photos first, then the rest.
List<ProductPublicImageRead> orderedImages(
  ProductPublicRead product,
  ProductPublicVariantRead? variant,
) {
  final own = variant?.imageIds ?? const <int>[];
  return [
    ...product.images.where((image) => own.contains(image.id)),
    ...product.images.where((image) => !own.contains(image.id)),
  ];
}

/// Non-variant-defining attributes as label/value rows, in the server's order.
List<SpecRow> specRows(
  ProductPublicRead product,
  AppLocale locale,
  TFunction t,
) => [
  for (final attribute in product.attributes)
    if (!attribute.isVariantDefining)
      SpecRow(
        pickTranslation(
              attribute.labelTranslations,
              (l) => l.locale,
              locale,
            )?.label ??
            attribute.key,
        _formatSpec(attribute, locale, t),
      ),
];

String _formatSpec(
  ProductPublicAttributeRead attribute,
  AppLocale locale,
  TFunction t,
) {
  final value = attribute.value;
  final text = switch (value) {
    final bool b => b ? t('product.yes') : t('product.no'),
    final List<dynamic> list => list.join(', '),
    final num n =>
      n == n.roundToDouble() ? formatNumber(n, locale.intlTag) : '$n',
    _ => '$value',
  };
  final unit = attribute.unit;
  return unit == null ? text : '$text $unit';
}
