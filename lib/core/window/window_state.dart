import 'dart:math' as math;
import 'dart:ui';

/// Tamanho usado quando nao ha estado salvo (ou o salvo e invalido).
const Size kDefaultWindowSize = Size(1280, 800);

/// Tamanho minimo desejado da janela.
const Size kDefaultMinimumWindowSize = Size(640, 480);

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
/// Picks the monitor a saved window belongs to and where to put it.
///
/// Returns the visible area of the display that holds the saved window's
/// title bar, and the saved position clamped into that display. When no
/// display holds it (monitor unplugged, layout changed) the result has a null
/// position: the caller centres on the primary display as before.
({Rect? display, Offset? position}) resolveWindowPlacement({
  required Offset? storedPosition,
  required Size size,
  required List<Rect> displays,
}) {
  if (storedPosition == null || displays.isEmpty) return (display: null, position: null);
  // Use the same fallback as resolveWindowState before computing bounds;
  // otherwise a corrupt 1x1 size can place the later 1280x800 window off screen.
  final effectiveSize = _isUsable(size) ? size : kDefaultWindowSize;
  // The draggable title bar must be on a screen; probe a point inside it.
  final probe = storedPosition + Offset(math.min(120, effectiveSize.width / 2), 16);
  Rect? display;
  for (final d in displays) {
    if (d.contains(probe)) {
      display = d;
      break;
    }
  }
  if (display == null) return (display: null, position: null);
  final w = math.min(effectiveSize.width, display.width);
  final h = math.min(effectiveSize.height, display.height);
  final left = storedPosition.dx.clamp(display.left, display.right - w).toDouble();
  final top = storedPosition.dy.clamp(display.top, display.bottom - h).toDouble();
  return (display: display, position: Offset(left, top));
}
