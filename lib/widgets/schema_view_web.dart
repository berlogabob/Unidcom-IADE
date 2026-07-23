// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, undefined_prefixed_name

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

const _viewType = 'unidcom-schema-diagram';
bool _registered = false;

/// Embeds web/schema.html (bundled mermaid + generated schema.mmd) in an iframe.
Widget schemaView() {
  if (!_registered) {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      return html.IFrameElement()
        ..src = 'schema.html'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
    });
    _registered = true;
  }
  return const HtmlElementView(viewType: _viewType);
}
