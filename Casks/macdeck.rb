cask "macdeck" do
  version "1.2.0"
  sha256 "0a5199020c00bdbcd81060d267ba29e9678e19dd2b3d9f05d20bbf17c451e410"

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
