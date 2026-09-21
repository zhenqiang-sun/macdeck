# Changelog

All notable changes to **MacDeck** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-09-21

### Added
- **External JSON Language Packs & i18n**:
  - Full-fledged language pack architecture (`en.json`, `zh-Hans.json`) completely decoupled from UI code.
  - Runtime dynamic language switching (System Follow, English, 简体中文) with sub-millisecond hot re-rendering.
  - Automated dual-language 1:1 key parity unit test assertion (`LocalizationTests`).
- **Apple Silicon Bento Dossier**:
  - Deep inspection of Apple Silicon heterogeneous CPU topology (P-cores / E-cores), GPU cores, and Neural Engine.
  - APFS physical storage watermark monitor with intelligent SMB/NFS share filtering.
  - High-concurrency racing public IP probe across 6 global CDN nodes with sub-second feedback.
  - Battery health condition, cycle counts, and AC power supply details.
  - Markdown full-system report one-click copy to clipboard.
- **Two-Tier Multi-Display Window Restorer**:
  - Organization by Physical Display Topology and customizable Window Presets.
  - In-place fullscreen Space retention via SkyLight private framework detection.
  - Multi-profile Google Chrome window distinction.
  - Automatic topology switching and hardware aliasing.
  - Optional auto-quit after window restoration (`⌘↵`) for zero background memory footprint.
- **Developer Environment Doctor & Maintenance**:
  - Automated diagnostics for Homebrew, Docker, Xcode CLT, Rust, Node.js, Pipx, and Volta.
  - Safe cache cleanup with interactive terminal drawer logs.
- **Multi-Source Package Update Hub**:
  - Aggregated detection and batch upgrade across Homebrew, Cargo, npm, Pipx, and Volta.
  - Package pinning, version ignoring, and rollback audit logs.
- **Open-Source Infrastructure**:
  - GNU General Public License v3.0 (`LICENSE`).
  - Bilingual documentation (`README.md`, `README_CN.md`).
  - GitHub Actions CI/CD workflows for automated build, test, and release packaging.
  - Homebrew Cask specification formula (`Casks/macdeck.rb`).

---

## [1.0.0] - 2026-09-14

### Added
- Initial proof-of-concept release for native window layout saving and restoring.
