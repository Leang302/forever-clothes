import 'dart:typed_data';

/// A pending KHQR order and the code the customer scans to pay it.
class KhqrPayment {
  const KhqrPayment({
    required this.orderId,
    required this.qrImage,
    required this.amount,
    required this.currency,
    required this.merchantName,
    required this.expiresAt,
    this.qrString,
    this.guestAccessToken,
  });

  final int orderId;

  /// PNG of the KHQR code as a base64 data URL.
  final String qrImage;
  final double amount;
  final String currency;
  final String merchantName;
  final DateTime expiresAt;

  /// The raw KHQR payload encoded in [qrImage].
  final String? qrString;

  /// Set only for an anonymous guest checkout (see `PlacedOrder.guestAccessToken`).
  final String? guestAccessToken;

  Uint8List get qrBytes => UriData.parse(qrImage).contentAsBytes();
}
