import 'package:flutter_test/flutter_test.dart';
import 'package:desky/features/updates/semver.dart';

SemVer _v(String raw) {
  final parsed = SemVer.tryParse(raw);
  if (parsed == null) {
    fail('nao deveria falhar ao parsear "$raw"');
  }
  return parsed;
}

void main() {
  group('SemVer.tryParse', () {
    test('le major, minor e patch', () {
      final v = _v('1.2.3');
      expect(v.major, equals(1));
      expect(v.minor, equals(2));
      expect(v.patch, equals(3));
      expect(v.isPreRelease, isFalse);
      expect(v.build, isEmpty);
    });

    test('aceita o prefixo v', () {
      expect(_v('v1.2.3'), equals(_v('1.2.3')));
    });

    test('separa pre-lancamento e build metadata', () {
      final v = _v('1.2.0-beta.1+build.19');
      expect(v.preRelease, equals(['beta', '1']));
      expect(v.build, equals(['build', '19']));
      expect(v.isPreRelease, isTrue);
    });

    test('minor e patch ausentes valem zero', () {
      expect(_v('2'), equals(_v('2.0.0')));
      expect(_v('2.1'), equals(_v('2.1.0')));
    });

    test('recusa o que nao e versao', () {
      for (final bad in ['', '   ', 'v', 'abc', '1.2.3.4', '1.x.3', '1.2.0-', '-1.2.3']) {
        expect(SemVer.tryParse(bad), isNull, reason: 'deveria recusar "$bad"');
      }
    });
  });

  group('SemVer precedencia (spec 11)', () {
    test('compara major, depois minor, depois patch', () {
      expect(_v('2.0.0') > _v('1.9.9'), isTrue);
      expect(_v('1.3.0') > _v('1.2.9'), isTrue);
      expect(_v('1.2.4') > _v('1.2.3'), isTrue);
      expect(_v('1.2.3') > _v('1.2.3'), isFalse);
    });

    test('pre-lancamento e menor que a versao final', () {
      expect(_v('1.2.0') > _v('1.2.0-rc.1'), isTrue);
      expect(_v('1.2.0-rc.1') < _v('1.2.0'), isTrue);
      expect(_v('1.2.0-beta.1') < _v('1.2.0'), isTrue);
    });

    test('beta.1 < beta.2 < rc.1 < final', () {
      final ordem = [
        _v('1.2.0-beta.1'),
        _v('1.2.0-beta.2'),
        _v('1.2.0-rc.1'),
        _v('1.2.0'),
      ];

      for (var i = 0; i < ordem.length - 1; i++) {
        expect(ordem[i] < ordem[i + 1], isTrue,
            reason: '${ordem[i]} deveria preceder ${ordem[i + 1]}');
        expect(ordem[i + 1] > ordem[i], isTrue);
      }
    });

    test('identificador numerico e menor que alfanumerico', () {
      expect(_v('1.2.0-alpha.1') < _v('1.2.0-alpha.beta'), isTrue);
    });

    test('identificadores numericos comparam como numero, nao como texto', () {
      // Como texto, "10" < "9"; como numero, 10 > 9.
      expect(_v('1.2.0-beta.9') < _v('1.2.0-beta.10'), isTrue);
    });

    test('mais identificadores vencem quando o prefixo e igual', () {
      expect(_v('1.2.0-alpha') < _v('1.2.0-alpha.1'), isTrue);
    });

    test('a ordem completa de exemplo da spec', () {
      final cadeia = [
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-alpha.beta',
        '1.0.0-beta',
        '1.0.0-beta.2',
        '1.0.0-beta.11',
        '1.0.0-rc.1',
        '1.0.0',
      ].map(_v).toList();

      for (var i = 0; i < cadeia.length - 1; i++) {
        expect(cadeia[i] < cadeia[i + 1], isTrue,
            reason: '${cadeia[i]} deveria preceder ${cadeia[i + 1]}');
      }
    });

    test('build metadata nao afeta a precedencia', () {
      expect(_v('1.2.0+a') == _v('1.2.0+b'), isTrue);
      expect(_v('1.2.0-beta.1+19') == _v('1.2.0-beta.1+20'), isTrue);
      expect(_v('1.2.0+18') == _v('1.2.0'), isTrue);
      expect(_v('1.2.0-beta.1+1') > _v('1.2.0-beta.1'), isFalse);
    });

    test('versao com build e maior quando o numero base e maior', () {
      expect(_v('1.1.8+1') > _v('1.1.7+18'), isTrue);
    });
  });
}