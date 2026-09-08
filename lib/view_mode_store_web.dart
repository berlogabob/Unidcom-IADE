// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _modeKey = 'view_mode';

/// Reads [key] from this tab's sessionStorage, if set.
///
/// sessionStorage, not localStorage: a choice made here should survive F5 —
/// Rui hits the mode chooser on every refresh otherwise — but die with the
/// tab, so a shared machine never inherits someone's admin mode or nav
/// collapse state.
String? loadStored(String key) => html.window.sessionStorage[key];

void store(String key, String? value) {
  if (value == null) {
    html.window.sessionStorage.remove(key);
  } else {
    html.window.sessionStorage[key] = value;
  }
}

/// The mode chosen in this tab, if any.
String? loadStoredMode() => loadStored(_modeKey);

void storeMode(String? mode) => store(_modeKey, mode);
