/// Stock rules shared by product detail, quick-add and the cart.
///
/// The API is the source of truth (it rejects over-stock adds with 409
/// OUT_OF_STOCK); these helpers only keep the UI from offering quantities the
/// server is going to refuse.
abstract final class StockRules {
  /// Upper bound of any quantity stepper, regardless of stock.
  static const maxPerLine = 99;

  /// "Only N left" is shown at or below this many units.
  static const lowStockThreshold = 5;

  /// Largest quantity a shopper may pick for a size with [stock] units left
  /// (0 when sold out, never more than [maxPerLine]).
  static int maxQuantity(int stock) =>
      stock <= 0 ? 0 : (stock > maxPerLine ? maxPerLine : stock);

  /// [quantity] pulled into `1..maxQuantity(stock)`; 0 when sold out.
  static int clampQuantity(int quantity, int stock) {
    final max = maxQuantity(stock);
    if (max == 0) return 0;
    if (quantity < 1) return 1;
    return quantity > max ? max : quantity;
  }

  /// Human label for a size's availability.
  static String label(int stock) {
    if (stock <= 0) return 'Out of stock';
    if (stock <= lowStockThreshold) return 'Only $stock left';
    return 'In stock';
  }
}
