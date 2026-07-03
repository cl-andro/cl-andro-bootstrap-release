# CL-Andro Bootstrap Builder

This repository contains the GitHub Actions workflow to compile, bundle, and release the developer environment bootstrap archive (`bootstrap-aarch64.zip`) for the CL-Andro terminal application.

The bootstrap includes base system utilities, package management (APT/dpkg), and network runtimes (curl, openssl), keeping the bootstrap size to **~42MB zipped**, ensuring the final compiled application APK is well within the **100MB - 120MB** target limit.
