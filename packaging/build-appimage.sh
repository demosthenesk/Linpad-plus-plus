#!/usr/bin/env bash
# Build the Linpad++ AppImage. Run on Ubuntu 24.04 x86_64.
# Build deps: sudo apt install python3.12-venv libxcb-cursor0 curl
#   packaging/build-appimage.sh            -> build/Linpad++-<version>-x86_64.AppImage
# Needs network access to PyPI and GitHub (appimagetool + type2 runtime) unless
# APPIMAGETOOL / RUNTIME / EXCLUDELIST point at local copies.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${BUILD:-$SRC/build}"
APPDIR="$BUILD/AppDir"
PY=python3.12
VERSION="$($PY -c "import re;print(re.search(r'VERSION = \"(.*?)\"', open('$SRC/linpad/__init__.py').read()).group(1))")"
OUT="$BUILD/Linpad++-$VERSION-x86_64.AppImage"
TOOLS="$BUILD/tools"
mkdir -p "$TOOLS"

fetch() { [ -s "$2" ] || curl -sSL -o "$2" "$1"; }
APPIMAGETOOL="${APPIMAGETOOL:-$TOOLS/appimagetool}"
RUNTIME="${RUNTIME:-$TOOLS/runtime-x86_64}"
EXCLUDELIST="${EXCLUDELIST:-$TOOLS/excludelist}"
fetch https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage "$APPIMAGETOOL"
fetch https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64 "$RUNTIME"
fetch https://raw.githubusercontent.com/AppImageCommunity/pkg2appimage/master/excludelist "$EXCLUDELIST"
chmod +x "$APPIMAGETOOL"

echo "== Linpad++ $VERSION"
rm -rf "$APPDIR"
LIBDIR="$APPDIR/usr/share/linpad/lib"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$LIBDIR" \
         "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/scalable/apps" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps" "$APPDIR/usr/share/metainfo"

# ---------------------------------------------------------------- Python 3.12
cp -L /usr/bin/python3.12 "$APPDIR/usr/bin/python3.12"
cp -a /usr/lib/python3.12 "$APPDIR/usr/lib/"
( cd "$APPDIR/usr/lib/python3.12" && rm -rf test idlelib tkinter turtledemo ensurepip lib2to3 pydoc_data \
    config-3.12-* dist-packages site-packages venv sitecustomize.py && \
  find . -name '__pycache__' -prune -exec rm -rf {} + && find . -type d -name tests -prune -exec rm -rf {} + )

# ---------------------------------------------------------- PyQt6 + QScintilla
VENV="$BUILD/venv"
[ -x "$VENV/bin/pip" ] || $PY -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade "PyQt6==6.12.*" "PyQt6-Qt6==6.12.*" "PyQt6-QScintilla==2.14.*" regex
SP="$("$VENV/bin/python" -c 'import site;print(site.getsitepackages()[0])')"
cp -a "$SP/regex" "$LIBDIR/"
mkdir -p "$LIBDIR/PyQt6"
cp -a "$SP/PyQt6/__init__.py" "$SP/PyQt6/sip"*.so "$LIBDIR/PyQt6/" 2>/dev/null || true
cp -a "$SP"/PyQt6/sip* "$LIBDIR/PyQt6/" 2>/dev/null || true
for m in QtCore QtGui QtWidgets QtNetwork QtPrintSupport QtSvg QtDBus Qsci; do
  cp -a "$SP/PyQt6/$m".abi3.so "$LIBDIR/PyQt6/"
done
mkdir -p "$LIBDIR/PyQt6/Qt6/lib" "$LIBDIR/PyQt6/Qt6/plugins"
cp -a "$SP/PyQt6/Qt6/qsci" "$LIBDIR/PyQt6/Qt6/" 2>/dev/null || true
QT="$SP/PyQt6/Qt6"
for l in Core Gui Widgets Network PrintSupport DBus Svg XcbQpa WaylandClient WaylandEglClientHwIntegration \
         OpenGL EglFSDeviceIntegration; do
  cp -a "$QT"/lib/libQt6$l.so* "$LIBDIR/PyQt6/Qt6/lib/" 2>/dev/null || true
done
cp -a "$QT"/lib/libicu*.so* "$LIBDIR/PyQt6/Qt6/lib/"
cp -a "$SP"/PyQt6/Qt6/lib/libqscintilla2_qt6.so* "$LIBDIR/PyQt6/Qt6/lib/" 2>/dev/null || true
for p in platforms platformthemes platforminputcontexts imageformats iconengines printsupport \
         xcbglintegrations wayland-decoration-client wayland-graphics-integration-client \
         wayland-shell-integration tls; do
  [ -d "$QT/plugins/$p" ] && cp -a "$QT/plugins/$p" "$LIBDIR/PyQt6/Qt6/plugins/"
done
rm -f "$LIBDIR"/PyQt6/Qt6/plugins/platforms/libqeglfs.so "$LIBDIR"/PyQt6/Qt6/plugins/platforms/libqlinuxfb.so \
      "$LIBDIR"/PyQt6/Qt6/plugins/platforms/libqvnc.so "$LIBDIR"/PyQt6/Qt6/plugins/platforms/libqvkkhrdisplay.so \
      "$LIBDIR"/PyQt6/Qt6/plugins/imageformats/libqpdf.so 2>/dev/null || true
[ -d "$QT/translations" ] && { mkdir -p "$LIBDIR/PyQt6/Qt6/translations"; cp -a "$QT"/translations/qtbase_*.qm "$LIBDIR/PyQt6/Qt6/translations/" 2>/dev/null || true; }

# drop plugins whose Qt dependencies were not bundled
check_qt_deps() {
  local f="$1"
  for need in $(ldd "$f" 2>/dev/null | awk '/libQt6/ {print $1}'); do
    [ -e "$LIBDIR/PyQt6/Qt6/lib/$need" ] || return 1
  done
  return 0
}
find "$LIBDIR/PyQt6/Qt6/plugins" -name '*.so' | while read -r f; do
  check_qt_deps "$f" || { echo "   drop plugin $(basename "$f")"; rm -f "$f"; }
done

# ------------------------------------------------------------------ the app
cp -a "$SRC/linpad" "$LIBDIR/"
find "$LIBDIR/linpad" -name '__pycache__' -prune -exec rm -rf {} +
cp "$SRC/LICENSE" "$APPDIR/usr/share/linpad/LICENSE"

# --------------------------------------------- host libraries not on the excludelist
EXCL="$(grep -v '^\s*#' "$EXCLUDELIST" | awk '{print $1}' | grep -v '^$' | sed 's/\.so.*//' | sort -u)"
is_excluded() { local b="${1%%.so*}"; grep -qx "$b" <<<"$EXCL"; }
collect() {
  ldd "$1" 2>/dev/null | awk '/=> \// {print $1" "$3}' | while read -r name path; do
    case "$path" in "$APPDIR"/*|/usr/local/*) continue;; esac
    is_excluded "$name" && continue
    case "$name" in libz.so*|libpython*|libQt6*|libicu*) continue;; esac
    # core system libraries every desktop already has; bundling them only risks clashes
    # with host modules loaded at runtime (GTK platform theme, input methods)
    case "$name" in libglib-2.0*|libgthread*|libgio-2*|libgobject*|libpcre2*|libdbus-1*|libsystemd*|libcap.so*|\
      libgcrypt*|libgpg-error*|liblz4*|libzstd*|libgssapi*|libkrb5*|libk5crypto*|libkeyutils*|libcom_err*|\
      libgnutls*|libp11-kit*|libidn2*|libunistring*|libtasn1*|libnettle*|libhogweed*|libgmp*|libbsd*|libmd.so*|\
      libXau*|libXdmcp*|libcrypt.so*|libdb-5*|libreadline*|libpanelw*|libncursesw*|libtinfo*|libavahi*|\
      libssl.so*|libcrypto.so*|libsqlite3*) continue;; esac
    # desktop toolkit stack: the GTK platform-theme plugin must use the host's own GTK
    case "$name" in libgtk-*|libgdk*|libgmodule*|libmount*|libblkid*|libselinux*|libcairo*|libpixman*|libpango*|\
      libthai*|libdatrie*|libgraphite2*|libepoxy*|libX*|libatk*|libatspi*|libjpeg*|libtiff*|libwebp*|librsvg*) continue;; esac
    [ -e "$APPDIR/usr/lib/$name" ] && continue
    cp -L "$path" "$APPDIR/usr/lib/$name" && echo "   + $name" && collect "$path"
  done
}
export LD_LIBRARY_PATH="$LIBDIR/PyQt6/Qt6/lib:$APPDIR/usr/lib"
for f in "$APPDIR/usr/bin/python3.12" $(find "$APPDIR/usr/lib/python3.12/lib-dynload" "$LIBDIR" -name '*.so*' -type f -not -path '*/platformthemes/*'); do
  collect "$f"
done
unset LD_LIBRARY_PATH

# --------------------------------------------------------- pre-compile .pyc
"$APPDIR/usr/bin/python3.12" -I -m compileall -q -j0 "$APPDIR/usr/lib/python3.12" "$LIBDIR/linpad" "$LIBDIR/regex" >/dev/null || true

# ------------------------------------------------- desktop integration + AppRun
cp "$SRC/packaging/linpad++.desktop" "$APPDIR/linpad++.desktop"
cp "$SRC/packaging/linpad++.desktop" "$APPDIR/usr/share/applications/"
cp "$SRC/packaging/io.github.linpadpp.Linpad.metainfo.xml" "$APPDIR/usr/share/metainfo/" 2>/dev/null || true
cp "$SRC/linpad/res/icons/linpad.svg" "$APPDIR/linpad++.svg"
cp "$SRC/linpad/res/icons/linpad.svg" "$APPDIR/usr/share/icons/hicolor/scalable/apps/linpad++.svg"
cp "$SRC/linpad/res/icons/linpad-256.png" "$APPDIR/.DirIcon"
cp "$SRC/linpad/res/icons/linpad-256.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/linpad++.png"
install -m 755 "$SRC/packaging/AppRun" "$APPDIR/AppRun"

# ------------------------------------------------------------------- squash
rm -f "$OUT"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGETOOL" --no-appstream --runtime-file "$RUNTIME" \
     --comp zstd "$APPDIR" "$OUT"
( cd "$(dirname "$OUT")" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256" )
du -h "$OUT"
