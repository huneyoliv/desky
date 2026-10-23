#!/usr/bin/env bash
# Script para construir e validar o PKGBUILD localmente no Arch Linux / CachyOS ou container Docker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARCH_DIR="${PROJECT_ROOT}/linux/archpkg"
BUILD_DIR="${PROJECT_ROOT}/build/archpkg"

if ! command -v makepkg &>/dev/null; then
  echo "⚠️  makepkg não encontrado no host. Tentando executar via container Docker (archlinux:latest)..."
  if command -v docker &>/dev/null; then
    docker run --rm -v "${PROJECT_ROOT}:/workspace" -w /workspace archlinux:latest bash -c "
      pacman -Sy --noconfirm base-devel sudo git &&
      useradd -m builder &&
      echo 'builder ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers &&
      chown -R builder:builder /workspace &&
      sudo -u builder bash /workspace/scripts/build_archpkg.sh
    "
    exit $?
  else
    echo "❌ Nem makepkg nem docker foram encontrados. Requer Arch Linux ou Docker para empacotamento."
    exit 1
  fi
fi

echo "==> Preparando diretório de build: ${BUILD_DIR}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

cp "${ARCH_DIR}/PKGBUILD" "${BUILD_DIR}/PKGBUILD"

# Se houver um tarball gerado localmente, utilizar seu sha256sum
LOCAL_TARBALL="${PROJECT_ROOT}/Desky-Linux-x64.tar.gz"
if [ -f "${LOCAL_TARBALL}" ]; then
  echo "==> Injetando tarball local: ${LOCAL_TARBALL}"
  SHA256=$(sha256sum "${LOCAL_TARBALL}" | cut -d' ' -f1)
  sed -i "s/sha256sums=('SKIP')/sha256sums=('${SHA256}')/" "${BUILD_DIR}/PKGBUILD"
  sed -i "s|source=.*|source=(\"Desky-Linux-x64.tar.gz\")|" "${BUILD_DIR}/PKGBUILD"
  cp "${LOCAL_TARBALL}" "${BUILD_DIR}/"
fi

cd "${BUILD_DIR}"
echo "==> Executando makepkg..."
makepkg --noconfirm --nodeps -f

echo "✅ Pacote Arch gerado com sucesso:"
ls -lh "${BUILD_DIR}/"*.pkg.tar.zst 2>/dev/null || true
