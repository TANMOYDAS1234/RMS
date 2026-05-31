// ─── FCM Background Handler — Web (no-op) ───────────────────────────────────
//
// Web doesn't use firebase_messaging at all (the package is currently
// incompatible with current firebase_core_web). Customers visiting the
// QR ordering page over the web don't need push notifications anyway.

void registerBackgroundHandler() {
  // intentionally empty
}
