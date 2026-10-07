cask "macdeck" do
  version "1.2.0"
  sha256 "85b3f89fcbca3a26b15965c8e77a525b83e90801b6d00df65de70678dd10539d"

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
