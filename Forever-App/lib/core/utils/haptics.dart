import 'package:flutter/services.dart';

abstract final class Haptics {
  static Future<void> tap() => HapticFeedback.selectionClick();
  static Future<void> light() => HapticFeedback.lightImpact();
  static Future<void> success() => HapticFeedback.mediumImpact();
  static Future<void> error() => HapticFeedback.heavyImpact();
}
