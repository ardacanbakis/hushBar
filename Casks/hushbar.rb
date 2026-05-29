cask "hushbar" do
  version "1.0"
  sha256 "PASTE_SHA256_HERE"

  url "https://github.com/ardacanbakis/hushBar/releases/download/v#{version}/HushBar-#{version}.dmg"
  name "HushBar"
  desc "Mute your microphone globally from the menu bar"
  homepage "https://ardacanbakis.github.io/hushBar/"

  depends_on macos: ">= :ventura"

  app "HushBar.app"

  zap trash: [
    "~/Library/Preferences/com.ardacanbakis.hushBar.plist",
  ]
end
