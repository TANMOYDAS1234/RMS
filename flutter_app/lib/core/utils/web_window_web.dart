// Web implementation of openInNewTab — uses window.open via dart:html.
// Only compiled when dart.library.html is available (i.e. web build).

import 'dart:html' as html;

void openInNewTab(String url) {
  // _blank → new tab; noopener for security so the AR page can't reach
  // back into the parent via window.opener.
  html.window.open(url, '_blank', 'noopener,noreferrer');
}
