cask "macdeck" do
  version "1.1.0"
  sha256 "7e92702c316edb603a46da6e545cd57f08f0560e24a0804a8ee0210efe3ff996"

  url "https://github.com/zhenqiang-sun/macdeck/releases/download/v#{version}/MacDeck-#{version}.dmg"
  name "MacDeck"
  desc "Native multi-display window restorer & developer environment toolkit"
  homepage "https://github.com/zhenqiang-sun/macdeck"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates false
  depends_on macos: ">= :ventura"

  app "MacDeck.app"

  zap trash: [
    "~/.config/macdeck",
    "~/Library/Preferences/com.agy.MacDeck.plist",
    "~/Library/Application Support/MacDeck",
  ]
end
