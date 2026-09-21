import XCTest
@testable import MacDeck

final class PackageParsersTests: XCTestCase {
    func testParseBrewOutdatedJsonV2() {
        let sampleJson = """
        {
          "formulae": [
            {
              "name": "node",
              "installed_versions": ["26.8.1"],
              "current_version": "26.8.2"
            }
          ],
          "casks": [
            {
              "name": "google-chrome",
              "installed_versions": ["152.0.7977.83"],
              "current_version": "153.0.8010.37"
            }
          ]
        }
        """

        let items = PackageParsers.parseBrewOutdated(jsonString: sampleJson)
        XCTAssertEqual(items.count, 2)

        let formula = items.first { $0.source == .brewFormula }
        XCTAssertNotNil(formula)
        XCTAssertEqual(formula?.rawName, "node")
        XCTAssertEqual(formula?.currentVersion, "26.8.1")
        XCTAssertEqual(formula?.latestVersion, "26.8.2")

        let cask = items.first { $0.source == .brewCask }
        XCTAssertNotNil(cask)
        XCTAssertEqual(cask?.rawName, "google-chrome")
        XCTAssertEqual(cask?.displayName, "Google Chrome")
        XCTAssertEqual(cask?.currentVersion, "152.0.7977.83")
        XCTAssertEqual(cask?.latestVersion, "153.0.8010.37")
    }

    func testParseNpmOutdatedJson() {
        let sampleJson = """
        {
          "wrangler": {
            "current": "4.129.0",
            "wanted": "4.131.1",
            "latest": "4.131.1"
          },
          "@larksuite/cli": {
            "current": "1.0.93",
            "wanted": "1.0.95",
            "latest": "1.0.95"
          }
        }
        """

        let items = PackageParsers.parseNpmOutdated(jsonString: sampleJson)
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(where: { $0.rawName == "wrangler" && $0.latestVersion == "4.131.1" }))
        XCTAssertTrue(items.contains(where: { $0.rawName == "@larksuite/cli" && $0.latestVersion == "1.0.95" }))
    }

    func testParseMasOutdatedOutput() {
        let sampleText = """
        497799835 Xcode (15.2 -> 15.3)
        1440147259 AdGuard for Safari (1.11.16 -> 1.11.17)
        """

        let items = PackageParsers.parseMasOutdated(outputString: sampleText)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].rawName, "497799835")
        XCTAssertEqual(items[0].displayName, "Xcode")
        XCTAssertEqual(items[0].currentVersion, "15.2")
        XCTAssertEqual(items[0].latestVersion, "15.3")
        XCTAssertEqual(items[0].source, .appStore)
    }

    func testParseInstalledBrew() {
        let casks = "google-chrome\ndocker-desktop\n"
        let formulae = "node\naliyun-cli\n"
        let items = PackageParsers.parseInstalledBrew(casksOutput: casks, formulaeOutput: formulae, outdatedMap: ["node": "26.8.2"])

        XCTAssertEqual(items.count, 4)
        let node = items.first { $0.rawName == "node" }
        XCTAssertEqual(node?.hasUpdate, true)
        XCTAssertEqual(node?.latestVersion, "26.8.2")

        let chrome = items.first { $0.rawName == "google-chrome" }
        XCTAssertEqual(chrome?.hasUpdate, false)
        XCTAssertEqual(chrome?.latestVersion, "最新")
    }

    func testParseInstalledNpm() {
        let json = """
        {
          "dependencies": {
            "wrangler": { "version": "4.129.0" },
            "bun": { "version": "1.4.2" }
          }
        }
        """
        let items = PackageParsers.parseInstalledNpm(jsonString: json, outdatedMap: ["wrangler": "4.131.1"])
        XCTAssertEqual(items.count, 2)
        let wrangler = items.first { $0.rawName == "wrangler" }
        XCTAssertEqual(wrangler?.hasUpdate, true)
        XCTAssertEqual(wrangler?.currentVersion, "4.129.0")
        XCTAssertEqual(wrangler?.latestVersion, "4.131.1")
    }

    func testParseInstalledVolta() {
        let sampleText = """
        ⚡️ User toolchain:

            Node runtimes:
                v20.19.4
                v24.19.0 (default)

            Package managers:
                npm:
                    v12.0.2 (default)

            Packages:
                @larksuite/cli@1.0.90 (default)
                    binary tools: lark-cli
                    platform:
                        runtime: node@24.19.0
                        package manager: npm@built-in
                @teable/cli@0.6.29 (default)
                    binary tools: teable
                    platform:
                        runtime: node@24.19.0
                        package manager: npm@built-in
                pnpm@11.23.0 (default)
                    binary tools: pnpm, pnpx, pn, pnx
                    platform:
                        runtime: node@24.19.0
                        package manager: npm@built-in
        """
        let items = PackageParsers.parseInstalledVolta(output: sampleText, outdatedMap: ["@teable/cli": "0.6.41"])
        XCTAssertEqual(items.count, 3)

        let teable = items.first { $0.rawName == "@teable/cli" }
        XCTAssertNotNil(teable)
        XCTAssertEqual(teable?.displayName, "@teable/cli")
        XCTAssertEqual(teable?.currentVersion, "0.6.29")
        XCTAssertEqual(teable?.latestVersion, "0.6.41")
        XCTAssertEqual(teable?.hasUpdate, true)
        XCTAssertEqual(teable?.source, .volta)

        let pnpm = items.first { $0.rawName == "pnpm" }
        XCTAssertNotNil(pnpm)
        XCTAssertEqual(pnpm?.currentVersion, "11.23.0")
        XCTAssertEqual(pnpm?.latestVersion, "最新")
        XCTAssertEqual(pnpm?.hasUpdate, false)
        XCTAssertEqual(pnpm?.source, .volta)
    }

    func testParseInstalledPipx() {
        let sampleJson = """
        {
          "pipx_spec_version": "0.1",
          "venvs": {
            "graphifyy": {
              "metadata": {
                "main_package": {
                  "package": "graphifyy",
                  "package_version": "0.9.54"
                }
              }
            },
            "black": {
              "metadata": {
                "main_package": {
                  "package": "black",
                  "package_version": "24.1.0"
                }
              }
            }
          }
        }
        """
        let items = PackageParsers.parseInstalledPipx(jsonString: sampleJson, outdatedMap: ["graphifyy": "0.9.64"])
        XCTAssertEqual(items.count, 2)

        let graphifyy = items.first { $0.rawName == "graphifyy" }
        XCTAssertNotNil(graphifyy)
        XCTAssertEqual(graphifyy?.currentVersion, "0.9.54")
        XCTAssertEqual(graphifyy?.latestVersion, "0.9.64")
        XCTAssertEqual(graphifyy?.hasUpdate, true)
        XCTAssertEqual(graphifyy?.source, .pipx)

        let black = items.first { $0.rawName == "black" }
        XCTAssertNotNil(black)
        XCTAssertEqual(black?.currentVersion, "24.1.0")
        XCTAssertEqual(black?.latestVersion, "最新")
        XCTAssertEqual(black?.hasUpdate, false)
        XCTAssertEqual(black?.source, .pipx)
    }

    func testParseInstalledCargo() {
        let sampleText = """
        cargo-update v22.1.1:
            cargo-install-update
            cargo-install-update-config
        ripgrep v14.1.0:
            rg
        """
        let items = PackageParsers.parseInstalledCargo(output: sampleText, outdatedMap: ["cargo-update": "23.0.0"])
        XCTAssertEqual(items.count, 2)

        let cargoUpdate = items.first { $0.rawName == "cargo-update" }
        XCTAssertNotNil(cargoUpdate)
        XCTAssertEqual(cargoUpdate?.currentVersion, "22.1.1")
        XCTAssertEqual(cargoUpdate?.latestVersion, "23.0.0")
        XCTAssertEqual(cargoUpdate?.hasUpdate, true)
        XCTAssertEqual(cargoUpdate?.source, .cargo)

        let rg = items.first { $0.rawName == "ripgrep" }
        XCTAssertNotNil(rg)
        XCTAssertEqual(rg?.currentVersion, "14.1.0")
        XCTAssertEqual(rg?.latestVersion, "最新")
        XCTAssertEqual(rg?.hasUpdate, false)
        XCTAssertEqual(rg?.source, .cargo)
    }

    func testParseCargoInstallUpdateList() {
        let sampleText = """
            Polling registry 'https://index.crates.io/'.

        Package       Installed  Latest   Needs update
        cargo-update  v22.1.1    v22.1.1  No
        ripgrep       v13.0.0    v14.1.0  Yes
        """
        let items = PackageParsers.parseCargoInstallUpdateList(output: sampleText)
        XCTAssertEqual(items.count, 1)

        let rg = items.first { $0.rawName == "ripgrep" }
        XCTAssertNotNil(rg)
        XCTAssertEqual(rg?.currentVersion, "13.0.0")
        XCTAssertEqual(rg?.latestVersion, "14.1.0")
        XCTAssertEqual(rg?.source, .cargo)
    }
}
