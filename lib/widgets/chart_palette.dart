import 'package:flutter/material.dart';

Color slotColor(int slot, Brightness brightness) {
  final colors = brightness == Brightness.dark ? _dark : _light;
  return colors[(slot - 1).clamp(0, colors.length - 1)];
}

const _light = [
  Color(0xff2a78d6),
  Color(0xffeb6834),
  Color(0xff1baf7a),
  Color(0xffeda100),
  Color(0xffe87ba4),
  Color(0xff008300),
  Color(0xff4a3aa7),
  Color(0xffe34948),
];

const _dark = [
  Color(0xff3987e5),
  Color(0xffd95926),
  Color(0xff199e70),
  Color(0xffc98500),
  Color(0xffd55181),
  Color(0xff008300),
  Color(0xff9085e9),
  Color(0xffe66767),
];
