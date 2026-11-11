default:
    @just --list

test:
    swift test --package-path PerihelionKit

build:
    swift build --package-path PerihelionKit

project:
    xcodegen generate

app device="iPhone 17":
    xcodebuild -project Perihelion.xcodeproj -scheme Perihelion -destination 'platform=iOS Simulator,name={{device}}' -derivedDataPath .build/xcode build

sim device="iPhone 17": (app device)
    xcrun simctl boot "{{device}}" || true
    open -a Simulator
    xcrun simctl install "{{device}}" .build/xcode/Build/Products/Debug-iphonesimulator/Perihelion.app
    xcrun simctl launch "{{device}}" io.github.glukicov.perihelion

autoplay device="iPhone 17": (app device)
    xcrun simctl install "{{device}}" .build/xcode/Build/Products/Debug-iphonesimulator/Perihelion.app
    xcrun simctl launch --terminate-running-process "{{device}}" io.github.glukicov.perihelion -PerihelionAutoplay YES

teams:
    defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier | grep -E 'teamID|teamName|isFreeProvisioningTeam'

phones:
    xcrun devicectl list devices

device phone:
    xcodebuild -project Perihelion.xcodeproj -scheme Perihelion -configuration Release -destination 'generic/platform=iOS' -derivedDataPath .build/device -allowProvisioningUpdates build
    xcrun devicectl device install app --device "{{phone}}" .build/device/Build/Products/Release-iphoneos/Perihelion.app
    xcrun devicectl device process launch --device "{{phone}}" io.github.glukicov.perihelion

archive:
    xcodebuild -project Perihelion.xcodeproj -scheme Perihelion -configuration Release -destination 'generic/platform=iOS' -archivePath .build/archive/Perihelion.xcarchive -allowProvisioningUpdates CURRENT_PROJECT_VERSION=$(date +%Y%m%d.%H%M) archive

testflight: archive
    xcodebuild -exportArchive -archivePath .build/archive/Perihelion.xcarchive -exportOptionsPlist Config/ExportOptions.plist -exportPath .build/archive/export -allowProvisioningUpdates

fixtures:
    node tools/reference.mjs

screenshots:
    node tools/screenshots.mjs

play version="2d":
    open web/perihelion-{{version}}.html

playtest:
    npm --prefix web/playtest install --no-audit --no-fund
    mkdir -p .playtest
    node web/playtest/play.mjs web/perihelion-2d.html .playtest

clean:
    rm -rf PerihelionKit/.build .playtest
