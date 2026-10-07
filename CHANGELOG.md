# Changelog

All notable changes to **MacDeck** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.1] - 2026-10-07

### Fixed
- **Multi-Display Window Restoration (Adaptive Convergence Loop)**:
  - Fixed an issue where restoring windows across displays with different resolutions or DPI required multiple clicks (2~3 times) to fully restore both size and position.
  - Introduced **Cross-Screen Safety Anchor**: Prioritizes moving window origins into the target display first with a 35ms scheduling yield, eliminating WindowServer boundary clamping.
  - Implemented **Adaptive Convergence Readback Loop**: Dynamically measures physical frame differences ($dx, dy, dw, dh \le 2.0\text{pt}$) and auto-compensates within 1 pass for instantaneous 1-click restoration.
  - Added smart physical limit stagnation detection for constraint-bound applications (Calculator, System Settings, fixed panels).

## [1.2.0] - 2026-10-07

### Added
- **Expanded Internationalization (i18n)**:
  - Added native **繁體中文 (`zh-Hant`)** and **日本語 (`ja`)** language packages with 100% 1:1 key parity (403 keys across all 4 locales).
  - Dynamic runtime language switching in Preferences supporting System Follow, English, 简体中文, 繁體中文, and 日本語.
  - Comprehensive unit test assertions validating parity and real-time formatting across all 4 language dictionaries.
- **Hardware Dossier Multi-Tier Cache & Instant Launch**:
  - Implemented persistent TTL and in-memory caching (`SystemDossierCache`) for static hardware specifications (CPU core layout, Apple Silicon GPU/NPU specs, battery design capacity, board IDs).
  - Eliminates cold-start freezing: System Dossier tab now loads instantly with background asynchronous cache refresh.
- **Enhanced Multi-Source Package Hub & Safety Audit**:
  - **In-Place Package State Transitions**: Upgrading packages dynamically update their row state and version tags immediately without full-list redraw glitches or button state mismatch.
  - **Batch Upgrade Live Streaming**: Consolidated terminal drawer logs with step-by-step progress tracking across Homebrew, npm, Cargo, Volta, and Pipx.
  - **Visual Safety Indicators**: Clear UI cues and context menus for pinned packages and ignored version updates.
- **Visual Polish & AppKit Synergy**:
  - Refined layout paddings, badge typography, and dark/light mode accent colors across all viewports.

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
