import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uptime_kuma_app/core/theme/app_tokens.dart';
import 'package:uptime_kuma_app/core/theme/palettes.dart';

/// Guards the "solid colours" switch: the header gradient is built from two
/// token stops, so a flat theme simply repeats one colour instead of adding a
/// second code path in the widget tree.
void main() {
  AppTokens tokens({required bool flat, required Brightness brightness}) =>
      AppTokens.build(
        style: UiStyle.kuma,
        accent: AccentPalette.all.first.color,
        brightness: brightness,
        flatGradients: flat,
      );

  for (final brightness in Brightness.values) {
    test('flat mode collapses both header stops (${brightness.name})', () {
      final flat = tokens(flat: true, brightness: brightness);
      expect(flat.flat, isTrue);
      expect(flat.headerFrom, flat.headerTo);

      final normal = tokens(flat: false, brightness: brightness);
      expect(normal.flat, isFalse);
      expect(normal.headerFrom, isNot(normal.headerTo),
          reason: 'the gradient needs two distinct stops');
    });
  }

  test('flat mode leaves the accent and status colours untouched', () {
    final flat = tokens(flat: true, brightness: Brightness.light);
    final normal = tokens(flat: false, brightness: Brightness.light);

    expect(flat.accent, normal.accent);
    expect(flat.statusUp, normal.statusUp);
    expect(flat.statusDown, normal.statusDown);
    expect(flat.surfaceCard, normal.surfaceCard);
  });
}
