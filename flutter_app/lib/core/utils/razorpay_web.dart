// ─── Razorpay Checkout — Web ────────────────────────────────────────────────
//
// Customer self-pay from the QR ordering page. razorpay_flutter is
// mobile-only, so on web we call Razorpay's Checkout JS directly via
// dart:js interop. The library is pre-loaded by web/index.html.
//
// Flow:
//   1. Caller passes a payment-init payload received from
//      POST /sessions/:id/pay/init (keyId, razorpayOrderId, amount …).
//   2. We instantiate `Razorpay(options)` and call `.open()`.
//   3. Razorpay's modal collects the payment and fires the success/dismiss
//      callbacks; we forward them to the Dart caller via a Completer.

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
// `allowInterop` lives behind package:js (re-exported from dart:js's
// private surface). Adding it as a direct dep just for this one symbol.
import 'package:js/js.dart' as pjs;

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
}) {
  final completer = Completer<RazorpayResult>();

  // The handler callbacks receive the Razorpay response object — we
  // pluck out the three fields we need to verify server-side.
  void onSuccess(dynamic response) {
    final r = js.JsObject.fromBrowserObject(response);
    completer.complete(RazorpayResult(
      razorpayOrderId: r['razorpay_order_id']?.toString(),
      razorpayPaymentId: r['razorpay_payment_id']?.toString(),
      razorpaySignature: r['razorpay_signature']?.toString(),
    ));
  }

  void onDismiss() {
    if (!completer.isCompleted) {
      completer.complete(const RazorpayResult(error: 'Payment cancelled.'));
    }
  }

  final options = js.JsObject.jsify({
    'key': keyId,
    'order_id': razorpayOrderId,
    'amount': amountPaise,
    'currency': 'INR',
    'name': name,
    'description': description,
    'theme': {'color': '#C87B3A'},
    'modal': {
      'ondismiss': pjs.allowInterop(onDismiss),
    },
    'handler': pjs.allowInterop(onSuccess),
  });

  // window.Razorpay is loaded by the <script> tag in web/index.html.
  final razorpayCtor = js.context['Razorpay'];
  if (razorpayCtor == null) {
    completer.complete(const RazorpayResult(error: 'Checkout library not loaded.'));
    return completer.future;
  }
  final rzp = js.JsObject(razorpayCtor as js.JsFunction, [options]);
  rzp.callMethod('open');
  return completer.future;
}
