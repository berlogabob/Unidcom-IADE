// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, undefined_prefixed_name

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

final _registered = <String>{};

/// Embeds a mermaid diagram host page (web/schema.html, which fetches a `.mmd`
/// via its `?src=` param) in an iframe. Defaults to the DB schema diagram.
Widget schemaView({String page = 'schema.html'}) {
  final viewType = 'unidcom-diagram:$page';
  if (_registered.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      return html.IFrameElement()
        ..src = page
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }
  return HtmlElementView(viewType: viewType);
}
