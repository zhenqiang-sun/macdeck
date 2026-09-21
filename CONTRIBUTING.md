# Contributing to MacDeck

Thank you for your interest in contributing to MacDeck! We welcome all contributions, including bug reports, documentation enhancements, feature proposals, and code improvements.

---

## 🛠️ Development Setup

### Prerequisites
- macOS 13.0 (Ventura) or later
- Xcode 15.0+ or Command Line Tools with Swift 6.0+
- Git

### Build & Run Locally
Clone the repository and compile using Swift Package Manager or the build script:

```bash
git clone https://github.com/zhenqiang-sun/macdeck.git
cd macdeck

# Run automated tests
swift test

# Build and generate MacDeck.app bundle
./scripts/build_app.sh
```

---

## 📋 Code Guidelines

1. **Swift Concurrency**: Always use modern Swift concurrency (`async/await`, `TaskGroup`, `@MainActor`, `nonisolated`) instead of legacy dispatch queues or callback pyramids where appropriate.
2. **Zero Third-Party Dependencies**: Keep the project lightweight and native. Avoid adding external CocoaPods/SPM packages unless absolutely essential and discussed prior.
3. **Internationalization (i18n)**: All user-facing strings must be localized through `LocalizationService` with both English and Simplified Chinese translations.
4. **Test Coverage**: Ensure all new features or bug fixes are accompanied by unit tests under `Tests/MacDeckTests/`. Verify with `swift test`.

---

## 🔀 Submitting a Pull Request

1. Fork the repository and create your feature branch:
   ```bash
   git checkout -b feature/my-new-feature
   ```
2. Commit your changes with clear, descriptive commit messages:
   ```bash
   git commit -m "feat: add support for pnpm package manager in updates hub"
   ```
3. Ensure all tests pass:
   ```bash
   swift test
   ```
4. Push to your branch and open a Pull Request against `master`.

---

## 📄 License Notice

By contributing to MacDeck, you agree that your contributions will be licensed under its [GNU General Public License v3.0 (GPL-3.0)](LICENSE).
