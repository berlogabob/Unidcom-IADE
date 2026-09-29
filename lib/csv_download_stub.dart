import 'dart:typed_data';

bool downloadText(String filename, String content, String mime) => false;
bool downloadCsv(String filename, String csv) => false;
bool downloadBytes(String filename, Uint8List bytes, String mime) => false;
Future<String?> pickTextFile() async => null;

/// Opens the browser picker for a JPEG/PNG/WebP photo; null on no selection.
Future<({Uint8List bytes, String name, String mime})?> pickImageFile() async => null;
