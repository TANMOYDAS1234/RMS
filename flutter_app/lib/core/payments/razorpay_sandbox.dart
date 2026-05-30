// ─── Razorpay Sandbox Gateway ────────────────────────────────────────────────
//
// Wraps the razorpay_flutter SDK so the billing screen can stay declarative.
// Opens the Razorpay checkout with the bill total and resolves with either
// success (paymentId + orderId) or failure (description string).
//
// Web/desktop fall back to manual confirmation — the SDK is mobile-only.
// In sandbox mode payments don't move real money but the entire UI flow
// works, including 3D Secure prompts, so this is enough to demo the
// happy path and the failure path.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpaySandboxResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? errorMessage;
  const RazorpaySandboxResult.ok({this.paymentId, this.orderId})
      : success = true,
        errorMessage = null;
  const RazorpaySandboxResult.failed(this.errorMessage)
      : success = false,
        paymentId = null,
        orderId = null;
}

class RazorpaySandbox {
  RazorpaySandbox._();
  static final RazorpaySandbox instance = RazorpaySandbox._();

  Razorpay? _razorpay;
  Completer<RazorpaySandboxResult>? _pending;

  void _ensureInit() {
    if (_razorpay != null) return;
    final r = Razorpay();
    r.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse rsp) {
      _pending?.complete(RazorpaySandboxResult.ok(
        paymentId: rsp.paymentId,
        orderId: rsp.orderId,
      ));
      _pending = null;
    });
    r.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse rsp) {
      _pending?.complete(RazorpaySandboxResult.failed(
          rsp.message ?? 'Payment failed (code ${rsp.code}).'));
      _pending = null;
    });
    r.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse rsp) {
      // External wallet (Paytm / Mobikwik) — treat as failure unless the
      // sandbox account is configured to return success.
      _pending?.complete(RazorpaySandboxResult.failed(
          'External wallet flow not completed (${rsp.walletName ?? "unknown"}).'));
      _pending = null;
    });
    _razorpay = r;
  }

  bool get isPlatformSupported {
    // razorpay_flutter is Android + iOS only. Web/desktop can't open the
    // checkout sheet, so the cashier has to use a different payment
    // method on those platforms.
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Open the sandbox checkout. [keyId] is the test key fetched from the
  /// server (sandbox: rzp_test_...). [amount] in whole rupees — the
  /// Razorpay SDK expects paise so we multiply by 100 here. [orderTag] is
  /// shown to the customer in the checkout UI (e.g. "T-01 / Bill 1234").
  Future<RazorpaySandboxResult> pay({
    required String keyId,
    required double amount,
    required String orderTag,
    String? customerName,
    String? customerContact,
    String? customerEmail,
  }) {
    if (!isPlatformSupported) {
      return Future.value(const RazorpaySandboxResult.failed(
          'Razorpay checkout is only available on mobile.'));
    }
    if (keyId.isEmpty) {
      return Future.value(const RazorpaySandboxResult.failed(
          'Razorpay key not configured. Set RAZORPAY_KEY_ID on the server.'));
    }
    _ensureInit();
    final completer = Completer<RazorpaySandboxResult>();
    _pending = completer;
    try {
      _razorpay!.open({
        'key': keyId,
        // Razorpay expects amount in the smallest currency unit (paise for
        // INR). 100 * rupees = paise.
        'amount': (amount * 100).round(),
        'currency': 'INR',
        'name': 'DINE OPS',
        'description': orderTag,
        'prefill': {
          if (customerName != null) 'name': customerName,
          if (customerContact != null) 'contact': customerContact,
          if (customerEmail != null) 'email': customerEmail,
        },
        'theme': {'color': '#E07B39'},
      });
    } catch (e) {
      completer.complete(RazorpaySandboxResult.failed('Failed to open Razorpay: $e'));
      _pending = null;
    }
    return completer.future;
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
    _pending = null;
  }
}
