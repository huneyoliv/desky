import 'dart:ui';

/// Tamanho usado quando nao ha estado salvo (ou o salvo e invalido).
const Size kDefaultWindowSize = Size(1280, 800);

/// Tamanho minimo desejado da janela.
const Size kDefaultMinimumWindowSize = Size(1024, 700);

/// Menor tamanho aceitavel como "estado salvo": abaixo disso consideramos o
/// valor corrompido e voltamos ao padrao.
const Size kMinimumUsableWindowSize = Size(640, 480);

/// Estado de janela pronto para ser aplicado na abertura.
class WindowStateSnapshot {
  const WindowStateSnapshot({
    required this.size,
    required this.minimumSize,
    this.maximized = false,
  });

  final Size size;
  final Size minimumSize;
  final bool maximized;
}

bool _isUsable(Size? size) {
  if (size == null) return false;
  final w = size.width;
  final h = size.height;
  if (!w.isFinite || !h.isFinite) return false;
  if (w < kMinimumUsableWindowSize.width || h < kMinimumUsableWindowSize.height) {
    return false;
  }
  return true;
}

/// Resolve o tamanho de abertura e o minimo, sem nunca passar da area util.
///
/// - sem valor salvo, valor invalido (zero, negativo, NaN/infinito) ou pequeno
///   demais: usa o tamanho padrao;
/// - um valor salvo maior que o monitor atual (resolucao ou monitor diferente)
///   e limitado a area util, o que tambem cobre o caso 720p;
/// - o minimo nunca passa da area util, senao a janela pediria mais espaco do
///   que a tela oferece.
WindowStateSnapshot resolveWindowState({
  required Size? storedSize,
  required bool storedMaximized,
  required Size? visibleArea,
  Size preferred = kDefaultWindowSize,
  Size minimum = kDefaultMinimumWindowSize,
}) {
  final screen = (visibleArea != null &&
          visibleArea.width.isFinite &&
          visibleArea.height.isFinite &&
          visibleArea.width > 0 &&
          visibleArea.height > 0)
      ? visibleArea
      : null;

  var resolved = _isUsable(storedSize) ? storedSize! : preferred;

  if (screen != null) {
    if (resolved.width > screen.width) resolved = Size(screen.width, resolved.height);
    if (resolved.height > screen.height) resolved = Size(resolved.width, screen.height);
  }

  var resolvedMinimum = minimum;
  if (screen != null) {
    if (resolvedMinimum.width > screen.width) {
      resolvedMinimum = Size(screen.width, resolvedMinimum.height);
    }
    if (resolvedMinimum.height > screen.height) {
      resolvedMinimum = Size(resolvedMinimum.width, screen.height);
    }
  }
  // O minimo nao pode ser maior que o tamanho inicial, senao o sistema recusa.
  if (resolvedMinimum.width > resolved.width) {
    resolvedMinimum = Size(resolved.width, resolvedMinimum.height);
  }
  if (resolvedMinimum.height > resolved.height) {
    resolvedMinimum = Size(resolvedMinimum.width, resolved.height);
  }

  return WindowStateSnapshot(
    size: resolved,
    minimumSize: resolvedMinimum,
    maximized: storedMaximized,
  );
}