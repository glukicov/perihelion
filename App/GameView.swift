import PerihelionCore
import SwiftUI

struct GameView: View {
    @State private var session = Session()
    @GestureState private var touching = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                ChartCanvas(session: session)
                    .onAppear { session.layout(size: proxy.size) }
                    .onChange(of: proxy.size) { _, size in session.layout(size: size) }
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($touching) { _, down, _ in
                        if !down {
                            down = true
                            session.touchDown()
                        }
                    }
            )

            Overlays(session: session)
        }
        .background(session.tint.ground.color.ignoresSafeArea())
        .onAppear { session.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.setPaused(true) }
        }
    }
}

private struct ChartCanvas: View {
    let session: Session

    var body: some View {
        let frame = session.frame
        Canvas(rendersAsynchronously: false) { context, size in
            _ = frame
            ChartRenderer.draw(context, size: size, session: session)
        }
        .accessibilityLabel("A star chart. Your comet circles a star until you tap to let go.")
    }
}

private struct Overlays: View {
    let session: Session

    var body: some View {
        let game = session.game
        ZStack {
            if game.mode == .title {
                TitleCard(records: session.records)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            if session.showsHUD {
                HUD(session: session)
            }
            if let banner = session.banner {
                BannerView(banner: banner)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            if let hint = session.hint, game.mode == .play {
                VStack {
                    Spacer()
                    Text(hint)
                        .font(Palette.display(17))
                        .foregroundStyle(Palette.chalk)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.22), in: Capsule())
                        .padding(.bottom, 40)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
            if game.mode == .dead {
                GameOverCard(session: session)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            if session.paused && !session.showsSettings {
                PauseCard(session: session)
            }
            if session.showsSettings {
                SettingsCard(session: session)
            }
        }
        .animation(.easeOut(duration: 0.35), value: game.mode)
        .animation(.easeOut(duration: 0.35), value: session.banner)
        .animation(.easeOut(duration: 0.35), value: session.hint)
        .animation(.easeOut(duration: 0.25), value: session.paused)
        .animation(.easeOut(duration: 0.25), value: session.showsSettings)
        .overlay(alignment: .topTrailing) {
            if (game.mode == .title || game.mode == .dead) && !session.showsSettings && !session.paused {
                Button { session.openSettings() } label: {
                    Text("ADJUST")
                        .font(Palette.mono(12, weight: .medium))
                        .tracking(1.8)
                        .foregroundStyle(Palette.chalk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .overlay(Rectangle().stroke(Palette.chalk.opacity(0.7), lineWidth: 1.2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Adjustments")
                .padding(.trailing, 20)
                .padding(.top, 16)
            }
        }
    }
}

private struct HUD: View {
    let session: Session

    var body: some View {
        let game = session.game
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(Int(session.shown.rounded()).formatted())
                            .font(Palette.display(44))
                            .monospacedDigit()
                            .contentTransition(.identity)
                        if game.flow > 0 {
                            Text("FLOW ×\(1 + game.flow)")
                                .font(Palette.mono(17, weight: .medium))
                                .foregroundStyle(Palette.comet)
                        }
                    }
                    Text(Catalog.starName(game.reached))
                        .font(Palette.display(17))
                    Lives(session: session)
                        .padding(.top, 2)
                }
                .foregroundStyle(Palette.chalk)
                .allowsHitTesting(false)
                Spacer()
                if game.mode == .play {
                    Button {
                        session.setPaused(true)
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.chalk)
                            .frame(width: 44, height: 44)
                            .overlay(Rectangle().stroke(Palette.chalk.opacity(0.7), lineWidth: 1.2).padding(4))
                    }
                    .accessibilityLabel("Pause")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            Spacer()
        }
    }
}

private struct Lives: View {
    let session: Session

    var body: some View {
        let game = session.game
        HStack(spacing: 5) {
            ForEach(0..<game.maxLives, id: \.self) { index in
                Image(systemName: index < game.lives ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(index < game.lives ? Palette.comet : Palette.chalk.opacity(0.38))
                    .scaleEffect(index == game.lives - 1 ? 1 + session.heartPulse * 0.4 : 1)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(game.lives) of \(game.maxLives) lives")
    }
}

private struct KeyGlyph: View {
    let kind: StarKind

    var body: some View {
        Canvas { context, size in
            let r = kind == .red ? 9.0 : kind == .blue ? 8.0 : 10.0
            drawGlyph(context, x: size.width / 2, y: size.height / 2, size: r * size.width / 24, kind: kind, charted: true,
                      color: tintColor(kind), lineWidth: 1.2)
        }
        .frame(width: 24, height: 24)
    }
}

private struct CTA: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Palette.comet).frame(width: 7, height: 7)
            Text(text.uppercased())
                .font(Palette.mono(13, weight: .medium))
                .tracking(3)
                .foregroundStyle(Palette.chalk)
        }
    }
}

private struct TitleCard: View {
    let records: Records

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Perihelion")
                .font(Palette.display(64))
                .foregroundStyle(Palette.chalk)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("Tap to let go of your star. Catch the next one before this one burns out.")
                .font(.custom("IowanOldStyle-Roman", size: 19))
                .foregroundStyle(Palette.chalk)
                .padding(.top, 8)
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                row(.white, "White stars hold steady.")
                row(.red, "Red giants swing wide and burn out fast.")
                row(.blue, "Blue stars spin tight and quick.")
            }
            Text("LEAVE ON YOUR FIRST LAP TO BUILD FLOW.")
                .font(Palette.mono(11))
                .tracking(1.6)
                .foregroundStyle(Palette.chalkDim)
                .padding(.top, 18)
            if records.hi > 0 {
                Text("BEST \(records.hi.formatted()) POINTS, FURTHEST \(Catalog.starName(records.far).uppercased())")
                    .font(Palette.mono(11))
                    .tracking(1.6)
                    .foregroundStyle(Palette.chalkDim)
                    .padding(.top, 6)
            }
            CTA(text: "Tap anywhere to begin")
                .padding(.top, 18)
        }
        .padding(.horizontal, 22)
        .padding(.top, 50)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ kind: StarKind, _ text: String) -> some View {
        HStack(spacing: 14) {
            KeyGlyph(kind: kind)
            Text(text)
                .font(.custom("IowanOldStyle-Roman", size: 17))
                .foregroundStyle(Palette.chalk)
        }
    }
}

private struct BannerView: View {
    let banner: Banner

    var body: some View {
        VStack(spacing: 6) {
            Text(banner.name)
                .font(Palette.display(40))
                .foregroundStyle(Palette.chalk)
            if !banner.rule.isEmpty {
                Text(banner.rule.uppercased())
                    .font(Palette.mono(12))
                    .tracking(2)
                    .foregroundStyle(Palette.chalkDim)
            }
        }
        .padding(.top, 150)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct GameOverCard: View {
    let session: Session

    var body: some View {
        let game = session.game
        let records = session.records
        VStack(alignment: .leading, spacing: 14) {
            Text(game.cause)
                .font(Palette.display(34))
                .foregroundStyle(Palette.chalk)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(game.score.formatted())
                    .font(Palette.display(64))
                    .foregroundStyle(Palette.comet)
                Text("points")
                    .font(Palette.display(20))
                    .foregroundStyle(Palette.chalkDim)
                if session.newBest {
                    Text("NEW BEST")
                        .font(Palette.mono(11, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(Palette.comet)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                stat("Reached", game.reached > 0 ? "\(Catalog.starName(game.reached)), star \(game.reached)" : "Nowhere past Sol")
                stat("Best flow", "×\(1 + game.stats.bestFlow)")
                stat("Dead centres", "\(game.stats.centres)")
                stat("Best score", records.hi.formatted())
            }
            CTA(text: "Tap to launch again")
                .padding(.top, 10)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.28))
        .padding(.horizontal, 12)
    }

    private func stat(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(key.uppercased())
                .font(Palette.mono(11))
                .tracking(1.5)
                .foregroundStyle(Palette.chalkDim)
            Text(value)
                .font(.custom("IowanOldStyle-Roman", size: 17))
                .foregroundStyle(Palette.chalk)
        }
    }
}

private struct PauseCard: View {
    let session: Session

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("Paused")
                    .font(Palette.display(44))
                    .foregroundStyle(Palette.chalk)
                HStack(spacing: 14) {
                    Button("Resume") { session.setPaused(false) }
                        .buttonStyle(ChartButton(primary: true))
                    Button("Start over") { session.restart() }
                        .buttonStyle(ChartButton(primary: false))
                }
                Button("Adjust") { session.openSettings() }
                    .buttonStyle(ChartButton(primary: false))
            }
        }
    }
}

private struct SettingsCard: View {
    let session: Session

    var body: some View {
        let duringPlay = session.game.mode == .play
        ZStack {
            Color.black.opacity(0.46).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                    Text("Adjustments")
                        .font(Palette.display(44))
                        .foregroundStyle(Palette.chalk)
                    slider(
                        "Difficulty",
                        value: difficultyName,
                        help: "Rings shrink, spin quickens, the fuse shortens and the launch speeds up as this rises. 1.00× is the original chart."
                    ) {
                        Slider(
                            value: Binding(get: { session.settings.difficulty }, set: { session.setDifficulty($0) }),
                            in: Tuning.difficultyMin...Tuning.difficultyMax
                        )
                    }
                    slider(
                        "Comet's reach",
                        value: reachName,
                        help: "How far the comet flies after you let go, before the dark takes it. 540 is the charted reach."
                    ) {
                        Slider(
                            value: Binding(get: { session.settings.cometRange }, set: { session.setCometRange($0) }),
                            in: Tuning.cometRangeMin...Tuning.cometRangeMax,
                            step: 10
                        )
                    }
                    slider(
                        "Lives",
                        value: "\(session.settings.startingLives)",
                        help: "A miss spends a heart and returns you to the last star you caught. Every \(Tuning.lifeMilestone) stars gives one back, up to this number."
                    ) {
                        Slider(
                            value: Binding(
                                get: { Double(session.settings.startingLives) },
                                set: { session.setStartingLives(Int($0.rounded())) }
                            ),
                            in: 1...Double(Tuning.maxStartingLives),
                            step: 1
                        )
                    }
                    Text(duringPlay
                         ? "Reach and hearts change this run. Difficulty redraws the next chart."
                         : "Difficulty redraws this chart when you close the panel.")
                        .font(.custom("IowanOldStyle-Roman", size: 16))
                        .foregroundStyle(Palette.chalkDim)
                    Button("Done") { session.closeSettings() }
                        .buttonStyle(ChartButton(primary: true))
                        .padding(.top, 4)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var difficultyName: String {
        let value = session.settings.difficulty
        let name = abs(value - 1) < 0.025 ? "As charted" : value < 1 ? "Gentle" : "Harsh"
        return "\(name) · \(String(format: "%.2f", value))×"
    }

    private var reachName: String {
        let reach = Int(session.settings.cometRange.rounded())
        return abs(session.settings.cometRange - Tuning.range) < 8 ? "\(reach) · charted" : "\(reach) units"
    }

    private func slider<Control: View>(_ title: String, value: String, help: String,
                                       @ViewBuilder control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(Palette.mono(11))
                    .tracking(1.6)
                    .foregroundStyle(Palette.chalkDim)
                Spacer()
                Text(value)
                    .font(Palette.display(20))
                    .foregroundStyle(Palette.comet)
            }
            control()
                .tint(Palette.comet)
            Text(help)
                .font(.custom("IowanOldStyle-Roman", size: 15))
                .foregroundStyle(Palette.chalk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ChartButton: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Palette.mono(14, weight: .medium))
            .tracking(1.5)
            .foregroundStyle(primary ? Color.black.opacity(0.8) : Palette.chalk)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(primary ? Palette.comet : Color.clear)
            .overlay(Rectangle().stroke(primary ? Palette.comet : Palette.chalk.opacity(0.7), lineWidth: 1.2))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
