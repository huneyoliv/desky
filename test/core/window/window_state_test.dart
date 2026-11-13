import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/window/window_state.dart';
import 'package:desky/core/window/window_state_store.dart';

void main() {
  group('resolveWindowState', () {
    test('sem valor salvo usa o tamanho padrao', () {
      final result = resolveWindowState(
        storedSize: null,
        storedMaximized: false,
        visibleArea: const Size(1920, 1080),
      );

      expect(result.size, equals(kDefaultWindowSize));
      expect(result.minimumSize, equals(kDefaultMinimumWindowSize));
      expect(result.maximized, isFalse);
    });

    test('valor salvo valido e restaurado', () {
      final result = resolveWindowState(
        storedSize: const Size(1100, 760),
        storedMaximized: false,
        visibleArea: const Size(1920, 1080),
      );

      expect(result.size, equals(const Size(1100, 760)));
    });

    test('valor salvo maior que a tela e limitado a area util (720p)', () {
      final result = resolveWindowState(
        storedSize: const Size(1600, 900),
        storedMaximized: false,
        visibleArea: const Size(1280, 720),
      );

      expect(result.size, equals(const Size(1280, 720)));
      // O minimo tambem nao pode passar da tela.
      expect(result.minimumSize.width, lessThanOrEqualTo(1280));
      expect(result.minimumSize.height, lessThanOrEqualTo(720));
    });

    test('padrao tambem e limitado quando nao cabe na tela', () {
      final result = resolveWindowState(
        storedSize: null,
        storedMaximized: false,
        visibleArea: const Size(1280, 720),
      );

      expect(result.size, equals(const Size(1280, 720)));
      expect(result.minimumSize.height, lessThanOrEqualTo(result.size.height));
    });

    test('valor salvo invalido volta ao padrao', () {
      for (final invalid in const [
        Size.zero,
        Size(-100, 500),
        Size(10, 10),
        Size(double.nan, 500),
        Size(double.infinity, 500),
      ]) {
        final result = resolveWindowState(
          storedSize: invalid,
          storedMaximized: false,
          visibleArea: const Size(1920, 1080),
        );
        expect(
          result.size,
          equals(kDefaultWindowSize),
          reason: 'tamanho invalido $invalid deveria ser ignorado',
        );
      }
    });

    test('minimo nunca e maior que o tamanho inicial', () {
      final result = resolveWindowState(
        storedSize: const Size(700, 500),
        storedMaximized: false,
        visibleArea: const Size(1920, 1080),
      );

      expect(result.minimumSize.width, lessThanOrEqualTo(result.size.width));
      expect(result.minimumSize.height, lessThanOrEqualTo(result.size.height));
    });

    test('estado maximizado e preservado', () {
      final result = resolveWindowState(
        storedSize: const Size(1100, 760),
        storedMaximized: true,
        visibleArea: const Size(1920, 1080),
      );

      expect(result.maximized, isTrue);
      // Mesmo maximizada, o tamanho de restauracao continua sendo o normal.
      expect(result.size, equals(const Size(1100, 760)));
    });

    test('sem informacao do monitor mantem o valor salvo', () {
      final result = resolveWindowState(
        storedSize: const Size(1600, 900),
        storedMaximized: false,
        visibleArea: null,
      );

      expect(result.size, equals(const Size(1600, 900)));
    });
  });

  group('WindowStateStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('grava e le o tamanho e o estado maximizado', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = WindowStateStore(prefs: prefs);

      await store.save(size: const Size(1234, 777), maximized: true);

      expect(await store.readSize(), equals(const Size(1234, 777)));
      expect(await store.readMaximized(), isTrue);
    });

    test('sem valor salvo devolve null e nao maximizado', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = WindowStateStore(prefs: prefs);

      expect(await store.readSize(), isNull);
      expect(await store.readMaximized(), isFalse);
    });

    test('largura ou altura ausente conta como inexistente', () async {
      SharedPreferences.setMockInitialValues({WindowStateStore.keyWidth: 900.0});
      final prefs = await SharedPreferences.getInstance();
      final store = WindowStateStore(prefs: prefs);

      expect(await store.readSize(), isNull);
    });

    test('valor corrompido no armazenamento e ignorado', () async {
      SharedPreferences.setMockInitialValues({
        WindowStateStore.keyWidth: -5.0,
        WindowStateStore.keyHeight: 0.0,
        WindowStateStore.keyMaximized: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = WindowStateStore(prefs: prefs);

      expect(await store.readSize(), isNull);
      // E o resolvedor volta ao padrao.
      final resolved = resolveWindowState(
        storedSize: await store.readSize(),
        storedMaximized: await store.readMaximized(),
        visibleArea: const Size(1920, 1080),
      );
      expect(resolved.size, equals(kDefaultWindowSize));
    });

    test('tamanho invalido nao sobrescreve o que ja estava salvo', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = WindowStateStore(prefs: prefs);

      await store.save(size: const Size(1200, 800), maximized: false);
      await store.save(size: Size.zero, maximized: true);

      expect(await store.readSize(), equals(const Size(1200, 800)));
      expect(await store.readMaximized(), isTrue);
    });
  });
}