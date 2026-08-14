// Non-web builds have no reload-loses-state problem; nothing to persist.
String? loadStoredMode() => null;

void storeMode(String? mode) {}
