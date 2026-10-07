cask "macdeck" do
  version "1.2.0"
  sha256 "813d4802332b738bbb319cecc6bb88bd41f01b9c84f47e66fdcd842e4faf6fbf"

  url "https://github.com/zhenqiang-sun/macdeck/releases/download/v#{version}/MacDeck-#{version}.dmg"
  name "MacDeck"
  desc "Native multi-display window restorer & developer environment toolkit"
  homepage "https://macdeck-app.vercel.app/"

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
