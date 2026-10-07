cask "macdeck" do
  version "1.2.0"
  sha256 "e48c1d89b00f63fdeebbf5d40a245e9c826da844b769f6b7bd8b2ae2c322af72"

  url "https://github.com/zhenqiang-sun/macdeck/releases/download/v#{version}/MacDeck-#{version}.dmg"
  name "MacDeck"
  desc "Native multi-display window restorer & developer environment toolkit"
  homepage "https://macdeck-app.vercel.app"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates false
  depends_on macos: :ventura

  app "MacDeck.app"

  zap trash: [
    "~/.config/macdeck",
    "~/Library/Preferences/com.agy.MacDeck.plist",
    "~/Library/Application Support/MacDeck",
  ]
end
