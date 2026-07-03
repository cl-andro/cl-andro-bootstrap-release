#!/bin/bash
set -e
echo "Forging Essential Sysroot..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR/cl-andro-packages-repo"
WORK_DIR="$SCRIPT_DIR/essential-work"
OUTPUT_ZIP="$SCRIPT_DIR/bootstrap-aarch64.zip"

# Essential package names (no version/arch suffixes)
ESSENTIALS=(
  # Base / Runtime
  ndk-sysroot libc++ libandroid-support libandroid-glob libbz2 liblzma
  libmd libandroid-posix-semaphore libgmp libmpfr pcre2 pcre2grep
  libandroid-selinux libcap-ng attr libacl libcrypt libffi
  # Terminal UI
  libiconv ncurses ncurses-ui-libs ncurses-utils readline
  # Crypto / Network
  ca-certificates zlib openssl openssl-tool libssh2 libnghttp2 libnghttp3
  brotli libngtcp2 libcurl resolv-conf libtalloc
  # Termux Core
  termux-core termux-exec termux-am termux-am-socket
  # APT & Package Management
  libgpg-error libgcrypt liblz4 xxhash zstd pzstd termux-licenses
  termux-keyring dpkg dpkg-scanpackages apt apt-ftparchive
  gpgv libassuan libnpth
  # GnuTLS (apt HTTPS support)
  libgnutls gnutls libidn2 libnettle nettle libunbound unbound libunistring
  # Core POSIX
  dash bash coreutils tar gzip grep sed gawk findutils diffutils less
  procps psmisc util-linux bzip2 lz4 xz-utils unzip
  # Misc tools
  dialog termux-tools nano file make db fdisk mount-utils uuid-utils blk-utils
  sqlite libsqlite c-ares libuv
)

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "Copying essential .deb files..."
for deb in "$REPO_DIR"/*.deb; do
    pkg=$(dpkg-deb --field "$deb" Package 2>/dev/null)
    for want in "${ESSENTIALS[@]}"; do
        if [ "$pkg" = "$want" ]; then
            cp "$deb" "$WORK_DIR/"
            break
        fi
    done
done

cd "$WORK_DIR"

echo "Generating SYMLINKS.txt..."
> SYMLINKS.txt
for deb in *.deb; do
    dpkg-deb -c "$deb" | grep '^l' | while read -r line; do
        link_full=$(echo "$line" | awk '{print $6}')
        target=$(echo "$line" | awk '{print $8}')
        link_path=$(echo "$link_full" | sed 's|^\./data/data/com.zk.clandro/files/usr/||')
        if [ -n "$link_path" ] && [ -n "$target" ]; then
            echo "${link_path}←${target}" >> SYMLINKS.txt
        fi
    done
done

echo "Extracting binaries..."
mkdir -p sysroot
for deb in *.deb; do
    dpkg-deb -x "$deb" sysroot/
done

echo "Restoring cl-andro.gpg keyring..."
mkdir -p sysroot/data/data/com.zk.clandro/files/usr/etc/apt/trusted.gpg.d/
rm -f sysroot/data/data/com.zk.clandro/files/usr/etc/apt/trusted.gpg.d/cl-andro.gpg
cp "$SCRIPT_DIR/cl-andro.gpg" sysroot/data/data/com.zk.clandro/files/usr/etc/apt/trusted.gpg.d/

echo "Fixing debs with wrong prefix (com.termux -> com.zk.clandro)..."
if [ -d sysroot/data/data/com.termux/files/usr ]; then
    cp -r sysroot/data/data/com.termux/files/usr/* sysroot/data/data/com.zk.clandro/files/usr/
    rm -rf sysroot/data/data/com.termux
fi

echo "Creating required directories..."
mkdir -p sysroot/data/data/com.zk.clandro/files/usr/etc/apt/apt.conf.d
mkdir -p sysroot/data/data/com.zk.clandro/files/usr/etc/apt/preferences.d
mkdir -p sysroot/data/data/com.zk.clandro/files/usr/tmp
mkdir -p sysroot/data/data/com.zk.clandro/files/usr/var/log/apt
mkdir -p sysroot/data/data/com.zk.clandro/files/usr/etc/ssl/certs

echo "Adding CA cert symlink to SYMLINKS.txt..."
echo "etc/ssl/certs/ca-certificates.crt←/data/data/com.zk.clandro/files/usr/etc/tls/cert.pem" >> SYMLINKS.txt

echo "Zipping payload..."
cd sysroot/data/data/com.zk.clandro/files/usr
mv "$WORK_DIR/SYMLINKS.txt" .
find . -type l -delete
rm -f "$OUTPUT_ZIP"
zip -r9 "$OUTPUT_ZIP" .

echo "Cleaning up..."
rm -rf "$WORK_DIR"
echo "Done!"
