#!/bin/sh
# Rebuilds payload/ from the official Gutenprint 5.3.5 source: download, verify SHA-1, compile for this Mac, generate the MP540 PPD.
# Needs the Xcode command line tools. No sudo; writes only to a temp dir and to the output dir (default: payload/ next to this script).
set -eu

VERSION=5.3.5
URL="https://downloads.sourceforge.net/project/gimp-print/gutenprint-5.3/$VERSION/gutenprint-$VERSION.tar.xz"
SHA1=65e1ad99e9a3df17d505e719a9123eaa3b50fd67
PREFIX=/Library/Printers/Gutenprint
MODEL=bjc-MULTIPASS-MP540

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$HERE/payload}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "==> Downloading Gutenprint $VERSION"
curl -fsSL -o "$WORK/gutenprint.tar.xz" "$URL"
echo "$SHA1  $WORK/gutenprint.tar.xz" | shasum -a 1 -c -

echo "==> Compiling"
tar -xf "$WORK/gutenprint.tar.xz" -C "$WORK"
cd "$WORK/gutenprint-$VERSION"
# The build forces _POSIX_C_SOURCE, which hides the BSD types (u_int) that the macOS CUPS headers need.
CFLAGS="-O2 -D_DARWIN_C_SOURCE" ./configure --prefix="$PREFIX" --with-cups \
  --disable-shared --enable-static --without-gimp2 --disable-libgutenprintui2 \
  --disable-samples --disable-escputil --disable-test --without-doc --disable-nls \
  --disable-globalized-cups-ppds --disable-cups-ppds > "$WORK/configure.log"
make -j"$(sysctl -n hw.ncpu)" > "$WORK/make.log"
make install DESTDIR="$WORK/stage" > "$WORK/install.log"

echo "==> Generating the PPD"
STAGE_DATA="$WORK/stage$PREFIX/share/gutenprint/5.3/xml"
# LC_ALL=C: under a French locale, cups-genppd writes "595,000" in the PostScript code, which CUPS rejects and then prints nothing.
LC_ALL=C STP_DATA_PATH="$STAGE_DATA" "$WORK/stage/usr/sbin/cups-genppd.5.3" -q -p "$WORK/ppd" "$MODEL"
gunzip "$WORK/ppd/stp-$MODEL.5.3.ppd.gz"

echo "==> Assembling $OUT"
rm -rf "$OUT"
mkdir -p "$OUT/Gutenprint/filter" "$OUT/Gutenprint/share/gutenprint/5.3" "$OUT/ppd"
cp "$WORK/stage/usr/libexec/cups/filter/rastertogutenprint.5.3" "$OUT/Gutenprint/filter/"
cp -R "$STAGE_DATA" "$OUT/Gutenprint/share/gutenprint/5.3/"
# SIP forbids installing into /usr/libexec/cups/filter, so the PPD points at the filter's absolute path; the default paper is A4.
sed -E \
  -e "s#rastertogutenprint\.5\.3\"#$PREFIX/filter/rastertogutenprint.5.3\"#" \
  -e 's#^\*Default(PageSize|PageRegion|ImageableArea|PaperDimension): Letter#*Default\1: A4#' \
  "$WORK/ppd/stp-$MODEL.5.3.ppd" > "$OUT/ppd/Canon-PIXMA-MP540-Gutenprint.ppd"
echo "$SHA1  gutenprint-$VERSION.tar.xz (SHA-1 verified against SourceForge)" > "$OUT/SOURCE.txt"

echo "==> Done"
