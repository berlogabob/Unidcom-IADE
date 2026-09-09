import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/main.dart';

void main() {
  test('parameterized routes key screens by their path parameter', () {
    const routes = {
      '/people/:id',
      '/outputs/:id',
      '/projects/:id',
      '/labs/:id',
      '/clusters/:id',
      '/objectives/:id',
      '/conferences/:key',
      '/app/requests/:id',
      '/app/admin/:tool',
      '/app/welcome/:section',
    };

    for (final route in routes) {
      final first = parameterizedRouteWidget(route, 'a');
      final second = parameterizedRouteWidget(route, 'b');
      expect(first.key, const ValueKey('a'), reason: route);
      expect(second.key, const ValueKey('b'), reason: route);
      expect(first.key, isNot(equals(second.key)), reason: route);
    }
  });
}
