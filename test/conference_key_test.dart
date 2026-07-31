import 'package:flutter_test/flutter_test.dart';
import 'package:unidcom_iade/data/supabase.dart';

void main() {
  String keyOf(String title) => conferenceKeyOf({'title': title});

  test('same venue with different role noise collapses to one key', () {
    expect(
      keyOf('Senses & Sensibility 2023 — Membro da comissão científica'),
      keyOf('Senses & Sensibility 2023 — Membro da comissão organizadora'),
    );
    expect(
      keyOf('Senses & Sensibility 2023 — Membro da comissão científica'),
      keyOf('Senses & Sensibility 2023'),
    );
  });

  test('parentheticals are ignored', () {
    expect(
      keyOf('Congresso Internacional de Design (SLIC 2025)'),
      keyOf('Congresso Internacional de Design'),
    );
  });

  test('leading role prefixes are stripped', () {
    expect(keyOf('Presentation: Design Futures'), keyOf('Design Futures'));
  });

  test('diacritics and punctuation are normalized', () {
    expect(
      keyOf('Organização de Seminários!'),
      keyOf('organizacao de seminarios'),
    );
  });

  test('different editions stay separate', () {
    expect(keyOf('IoT 2024'), isNot(keyOf('IoT 2023')));
  });

  test('display name keeps the surviving segment verbatim', () {
    expect(
      conferenceNameOf({
        'title': 'Senses & Sensibility 2023 — Membro da comissão científica',
      }),
      'Senses & Sensibility 2023',
    );
  });
}
