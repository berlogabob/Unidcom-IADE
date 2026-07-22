// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

bool downloadText(String filename, String content, String mime) {
  final blob = html.Blob([content], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}

bool downloadCsv(String filename, String csv) =>
    downloadText(filename, csv, 'text/csv;charset=utf-8');

/// Opens the browser file picker and returns the chosen file's text, or null
/// on non-web / no selection. Cancelling the dialog fires no event, so the
/// Future simply never completes for that attempt (matches the file input).
Future<String?> pickTextFile() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()..accept = '.json,application/json';
  input.onChange.listen((_) {
    final file = (input.files?.isNotEmpty ?? false) ? input.files!.first : null;
    if (file == null) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader()..readAsText(file);
    reader.onLoadEnd.listen((_) => completer.complete(reader.result as String?));
    reader.onError.listen((_) => completer.completeError('Could not read file'));
  });
  input.click();
  return completer.future;
}
