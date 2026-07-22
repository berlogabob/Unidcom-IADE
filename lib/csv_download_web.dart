// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

bool downloadCsv(String filename, String csv) {
  final blob = html.Blob([csv], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}
