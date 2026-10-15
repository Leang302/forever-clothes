import 'package:intl/intl.dart';

import '../config/app_config.dart';

/// "$100" for whole prices, "$19.99" otherwise (product cards).
String formatPrice(double value) {
  final whole = value == value.roundToDouble();
  return '${AppConfig.currencySymbol}${whole ? value.toStringAsFixed(0) : value.toStringAsFixed(2)}';
}

/// "$610.00" (totals).
String formatMoney(double value) =>
    '${AppConfig.currencySymbol}${value.toStringAsFixed(2)}';

String formatDate(DateTime date) => DateFormat('d MMM yyyy').format(date);
