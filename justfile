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
