import 'dart:io';

import 'package:desky/core/pdf/single_instance_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  final abertos = <SingleInstanceChannel>[];

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('desky_single_instance_');
  });

  tearDown(() async {
    // Fecha os canais antes de apagar: no Windows o socket e a trava mantem o
    // diretorio em uso e a remocao falharia com errno 32.
    for (final channel in abertos) {
      await channel.dispose();
    }
    abertos.clear();
    try {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    } on FileSystemException {
      // Diretorio temporario remanescente nao invalida o teste.
    }
  });

  group('SingleInstanceChannel.startOrForward', () {
    test('vira primaria e publica a porta no diretorio informado', () async {
      final dir = Directory('${temp.path}${Platform.pathSeparator}canal');

      final result = await SingleInstanceChannel.startOrForward(
        '',
        directory: dir,
      );
      abertos.add(result.channel!);

      expect(result.outcome, SingleInstanceOutcome.primary);
      expect(result.isPrimary, isTrue);
      expect(result.shouldExit, isFalse);

      final portFile = File(
        '${dir.path}${Platform.pathSeparator}desky.instance.port',
      );
      expect(await portFile.exists(), isTrue);
      final port = int.tryParse((await portFile.readAsString()).trim());
      expect(port, isNotNull);
      expect(port, greaterThan(0));
    });

    test('a segunda instancia encaminha o payload e deve encerrar', () async {
      final dir = Directory('${temp.path}${Platform.pathSeparator}canal');
      final primary = await SingleInstanceChannel.startOrForward(
        '',
        directory: dir,
      );
      abertos.add(primary.channel!);
      expect(primary.outcome, SingleInstanceOutcome.primary);

      final received = primary.channel!.incoming.first;
      final second = await SingleInstanceChannel.startOrForward(
        r'C:\docs\prova.pdf',
        directory: dir,
      );

      expect(second.outcome, SingleInstanceOutcome.forwarded);
      expect(second.channel, isNull);
      expect(second.shouldExit, isTrue);
      expect(await received.timeout(const Duration(seconds: 5)),
          r'C:\docs\prova.pdf');
    });

    test(
      'diretorio inutilizavel degrada em vez de encerrar o processo',
      () async {
        // Um arquivo comum no lugar do diretorio: `create` falha sempre, entao
        // nem a trava nem a entrega funcionam. O app tem de continuar abrindo.
        final blocker = File('${temp.path}${Platform.pathSeparator}bloqueio');
        await blocker.writeAsString('nao sou um diretorio');

        final result = await SingleInstanceChannel.startOrForward(
          '',
          directory: Directory(blocker.path),
        );

        expect(result.outcome, SingleInstanceOutcome.degraded);
        expect(result.channel, isNull);
        expect(result.shouldExit, isFalse,
            reason: 'encerrar aqui era o bug: app morria sem janela');
      },
    );
  });

  group('SingleInstanceChannel.acquire', () {
    test('permite no maximo um primario em chamadas concorrentes', () async {
      final dir = Directory('${temp.path}${Platform.pathSeparator}concorrente');
      final results = await Future.wait([
        SingleInstanceChannel.acquire(directory: dir),
        SingleInstanceChannel.acquire(directory: dir),
      ]);
      final channels = results.whereType<SingleInstanceChannel>().toList();
      abertos.addAll(channels);

      expect(channels, hasLength(1));
    });

    test('dispose libera o caminho para uma nova aquisicao', () async {
      final dir = Directory('${temp.path}${Platform.pathSeparator}reaquisicao');
      final first = await SingleInstanceChannel.acquire(directory: dir);
      expect(first, isNotNull);
      abertos.add(first!);
      await first.dispose();

      final second = await SingleInstanceChannel.acquire(directory: dir);
      expect(second, isNotNull);
      abertos.add(second!);
    });
  });
}
