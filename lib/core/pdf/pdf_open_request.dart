import 'dart:io';

/// Resultado do tratamento do argumento de linha de comando.
enum PdfOpenOutcome {
  /// Nenhum argumento de arquivo foi passado.
  none,

  /// Caminho valido e com extensao .pdf.
  valid,

  /// O caminho nao existe.
  missing,

  /// O caminho existe, mas e um diretorio.
  notAFile,

  /// O arquivo existe mas nao e PDF.
  notPdf,
}

/// Pedido de abertura de PDF originado na linha de comando.
///
/// Separado da UI para poder ser testado sem subir o app: [parse] recebe os
/// argumentos crus e uma sonda de sistema de arquivos injetavel.
class PdfOpenRequest {
  const PdfOpenRequest(this.outcome, {this.path});

  final PdfOpenOutcome outcome;
  final String? path;

  bool get shouldOpen => outcome == PdfOpenOutcome.valid && path != null;

  /// `true` quando o usuario passou algo que nao pode ser aberto: permite
  /// avisar em vez de abrir o app silenciosamente.
  bool get failed => outcome == PdfOpenOutcome.missing ||
      outcome == PdfOpenOutcome.notAFile ||
      outcome == PdfOpenOutcome.notPdf;

  static const PdfOpenRequest none = PdfOpenRequest(PdfOpenOutcome.none);

  /// Extrai o primeiro argumento que parece um caminho de arquivo.
  ///
  /// Argumentos iniciados por `-`/`--` sao ignorados (flags de launcher, que
  /// podem chegar antes do caminho em integracoes de desktop). O primeiro
  /// argumento util e classificado; os seguintes sao ignorados, porque abrir
  /// varios PDFs de uma vez nao esta suportado.
  static PdfOpenRequest parse(
    List<String> args, {
    bool Function(String path)? exists,
    bool Function(String path)? isDirectory,
  }) {
    final candidate = _firstFileArgument(args);
    if (candidate == null) return none;

    final existsFn = exists ?? (p) => FileSystemEntity.typeSync(p) != FileSystemEntityType.notFound;
    final isDirFn = isDirectory ?? (p) => FileSystemEntity.isDirectorySync(p);

    if (!existsFn(candidate)) {
      return PdfOpenRequest(PdfOpenOutcome.missing, path: candidate);
    }
    if (isDirFn(candidate)) {
      return PdfOpenRequest(PdfOpenOutcome.notAFile, path: candidate);
    }
    if (!_hasPdfExtension(candidate)) {
      return PdfOpenRequest(PdfOpenOutcome.notPdf, path: candidate);
    }
    return PdfOpenRequest(PdfOpenOutcome.valid, path: candidate);
  }

  static String? _firstFileArgument(List<String> args) {
    for (final raw in args) {
      final arg = raw.trim();
      if (arg.isEmpty) continue;
      if (arg.startsWith('-')) continue;
      final unquoted = _stripWrappingQuotes(arg);
      if (unquoted.isEmpty) continue;
      return unquoted;
    }
    return null;
  }

  static String _stripWrappingQuotes(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        return value.substring(1, value.length - 1).trim();
      }
    }
    return value;
  }

  static bool _hasPdfExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return false;
    return path.substring(dot).toLowerCase() == '.pdf';
  }

  /// Nome exibido no titulo do leitor.
  String? get fileName {
    final p = path;
    if (p == null) return null;
    final sep = Platform.pathSeparator;
    final normalized = p.replaceAll(sep == '/' ? '\\' : '/', sep);
    final parts = normalized.split(sep);
    return parts.isEmpty ? p : parts.last;
  }

  @override
  String toString() => 'PdfOpenRequest(${outcome.name}${path == null ? '' : ': $path'})';
}