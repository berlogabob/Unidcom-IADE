// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _key = 'view_mode';

/// The mode chosen in this tab, if any.
///
/// sessionStorage, not localStorage: the choice should survive F5 — Rui hits
/// the chooser on every refresh otherwise — but die with the tab, so a shared
/// machine never inherits someone's admin mode.
String? loadStoredMode() => html.window.sessionStorage[_key];

void storeMode(String? mode) {
  if (mode == null) {
    html.window.sessionStorage.remove(_key);
  } else {
    html.window.sessionStorage[_key] = mode;
  }
}
