// Stub for non-web platforms — see razorpay_checkout.dart for the facade.

class RazorpayResult {
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final String? error;
  bool get success => error == null && razorpayPaymentId != null;

  const RazorpayResult({
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    this.error,
  });
}

Future<RazorpayResult> openRazorpayCheckout({
  required String keyId,
  required String razorpayOrderId,
  required int amountPaise,
  required String name,
  required String description,
}) async {
  return const RazorpayResult(
    error: 'Web payment is only available from the browser.',
  );
}
