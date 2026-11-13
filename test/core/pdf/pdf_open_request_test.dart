import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/pdf/pdf_open_request.dart';

void main() {
  group('PdfOpenRequest.parse', () {
    test('sem argumentos nao abre nada', () {
      final request = PdfOpenRequest.parse(const []);

      expect(request.outcome, PdfOpenOutcome.none);
      expect(request.shouldOpen, isFalse);
      expect(request.failed, isFalse);
      expect(request.path, isNull);
    });

    test('caminho valido para um PDF vira pedido de abertura', () {
      final request = PdfOpenRequest.parse(
        const ['C:/docs/apostila.pdf'],
        exists: (_) => true,
        isDirectory: (_) => false,
      );

      expect(request.outcome, PdfOpenOutcome.valid);
      expect(request.shouldOpen, isTrue);
      expect(request.failed, isFalse);
      expect(request.path, equals('C:/docs/apostila.pdf'));
      expect(request.fileName, equals('apostila.pdf'));
    });

    test('caminho inexistente e reportado como falha', () {
      final request = PdfOpenRequest.parse(
        const ['C:/docs/nao-existe.pdf'],
        exists: (_) => false,
        isDirectory: (_) => false,
      );

      expect(request.outcome, PdfOpenOutcome.missing);
      expect(request.shouldOpen, isFalse);
      expect(request.failed, isTrue);
    });

    test('caminho que existe mas nao e PDF e recusado', () {
      final request = PdfOpenRequest.parse(
        const ['C:/docs/foto.jpg'],
        exists: (_) => true,
        isDirectory: (_) => false,
      );

      expect(request.outcome, PdfOpenOutcome.notPdf);
      expect(request.shouldOpen, isFalse);
      expect(request.failed, isTrue);
    });

    test('arquivo sem extensao e recusado', () {
      final request = PdfOpenRequest.parse(
        const ['C:/docs/arquivo'],
        exists: (_) => true,
        isDirectory: (_) => false,
      );

      expect(request.outcome, PdfOpenOutcome.notPdf);
    });

    test('diretorio e recusado', () {
      final request = PdfOpenRequest.parse(
        const ['C:/docs'],
        exists: (_) => true,
        isDirectory: (_) => true,
      );

      expect(request.outcome, PdfOpenOutcome.notAFile);
      expect(request.failed, isTrue);
    });

    test('extensao .PDF em maiusculas tambem abre', () {
      final request = PdfOpenRequest.parse(
        const ['C:/docs/APOSTILA.PDF'],
        exists: (_) => true,
        isDirectory: (_) => false,
      );

      expect(request.outcome, PdfOpenOutcome.valid);
    });

    test('flags de launcher sao ignoradas antes do caminho', () {
      final request = PdfOpenRequest.parse(
        const ['--enable-impeller', '-v', 'C:/docs/apostila.pdf'],
        exists: (_) => true,
        isDirectory: (_) => false,
      );

      expect(request.outcome, PdfOpenOutcome.valid);
      expect(request.path, equals('C:/docs/apostila.pdf'));
    });

    test('apenas flags, sem arquivo, resulta em none', () {
      final request = PdfOpenRequest.parse(
        const ['--enable-impeller', '-v'],
        exists: (_) => true,
        isDirectory: (_) => false,
      );

      expect(request.outcome, PdfOpenOutcome.none);
    });

    test('caminho entre aspas e desembrulhado', () {
      final request = PdfOpenRequest.parse(
        const ['"C:/Meus Documentos/apostila.pdf"'],
        exists: (_) => true,
        isDirectory: (_) => false,
      );

      expect(request.outcome, PdfOpenOutcome.valid);
      expect(request.path, equals('C:/Meus Documentos/apostila.pdf'));
    });

    test('apenas o primeiro arquivo e considerado', () {
      final request = PdfOpenRequest.parse(
        const ['a.pdf', 'b.pdf'],
        exists: (_) => true,
        isDirectory: (_) => false,
      );

      expect(request.path, equals('a.pdf'));
    });

    test('integra com o sistema de arquivos real', () async {
      final dir = await Directory.systemTemp.createTemp('desky_pdf_test');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final pdf = File('${dir.path}${Platform.pathSeparator}real.pdf');
      await pdf.writeAsString('%PDF-1.4');

      final ok = PdfOpenRequest.parse([pdf.path]);
      expect(ok.outcome, PdfOpenOutcome.valid);

      final txt = File('${dir.path}${Platform.pathSeparator}real.txt');
      await txt.writeAsString('nao e pdf');
      expect(PdfOpenRequest.parse([txt.path]).outcome, PdfOpenOutcome.notPdf);

      final missing = PdfOpenRequest.parse(
        ['${dir.path}${Platform.pathSeparator}nada.pdf'],
      );
      expect(missing.outcome, PdfOpenOutcome.missing);

      expect(PdfOpenRequest.parse([dir.path]).outcome, PdfOpenOutcome.notAFile);
    });
  });
}