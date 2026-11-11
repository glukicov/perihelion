default:
    @just --list

test:
    swift test --package-path PerihelionKit

build:
    swift build --package-path PerihelionKit

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
