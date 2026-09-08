// Non-web builds have no reload-loses-state problem; nothing to persist.
String? loadStored(String key) => null;

void store(String key, String? value) {}

String? loadStoredMode() => loadStored('view_mode');

void storeMode(String? mode) => store('view_mode', mode);
