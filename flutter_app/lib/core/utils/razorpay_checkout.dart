// ─── Razorpay Checkout — platform-conditional facade ────────────────────────
//
// Web → wires the customer Pay Now flow to Razorpay Checkout JS via
// dart:js interop. Mobile → no-op stub that returns an "unavailable"
// result so callers degrade gracefully (the mobile staff app uses
// razorpay_flutter on its own paths).

export 'razorpay_checkout_stub.dart'
    if (dart.library.html) 'razorpay_web.dart';
