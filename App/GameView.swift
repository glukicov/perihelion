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

            Veil()
            Palette.scrim
                .opacity(session.showsScrim ? 0.66 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(session.calm ? nil : .easeOut(duration: 0.35), value: session.showsScrim)

            Overlays(session: session)
        }
        .background(session.tint.ground.color.ignoresSafeArea())
        .onAppear { session.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.setPaused(true) }
            if phase == .active { session.foreground() }
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

private struct Veil: View {
    var body: some View {
        GeometryReader { geo in
            RadialGradient(
                stops: [
                    .init(color: .clear, location: 0.42),
                    .init(color: Palette.veil.opacity(0.55), location: 1),
                ],
                center: UnitPoint(x: 0.5, y: 0.45),
                startRadius: 0,
                endRadius: max(geo.size.width, geo.size.height)
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct Overlays: View {
    let session: Session

    var body: some View {
        let game = session.game
        ZStack {
            if game.mode == .title {
                TitleCard(records: session.records, calm: session.calm)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            if session.showsPlayChrome {
                PlayChrome(session: session)
                    .transition(.opacity)
            }
            if game.mode == .dead {
                GameOverCard(session: session)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            if session.paused && !session.showsSettings {
                PauseCard(session: session)
                    .transition(.opacity)
            }
            if session.showsSettings {
                SettingsCard(session: session)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !session.showsPlayChrome && !session.showsSettings {
                VStack(alignment: .trailing, spacing: 10) {
                    SoundControl(session: session)
                    if game.mode == .title || game.mode == .dead {
                        Button { session.openSettings() } label: {
                            Text("Adjust")
                        }
                        .buttonStyle(ChartButton(primary: false))
                        .accessibilityLabel("Adjustments")
                    }
                }
                .padding(.top, 8)
                .padding(.trailing, 14)
            }
        }
        .animation(session.calm ? nil : .easeOut(duration: 0.35), value: game.mode)
        .animation(session.calm ? nil : .easeOut(duration: 0.6), value: session.banner)
        .animation(session.calm ? nil : .easeOut(duration: 0.3), value: session.hint)
        .animation(session.calm ? nil : .easeOut(duration: 0.25), value: session.paused)
        .animation(session.calm ? nil : .easeOut(duration: 0.25), value: session.showsSettings)
    }
}

private struct PlayChrome: View {
    let session: Session

    var body: some View {
        let game = session.game
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text(Palette.points(Int(session.shown.rounded())))
                    .font(Palette.display(54))
                    .foregroundStyle(Palette.chalk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                VStack(alignment: .leading, spacing: 3) {
                    if game.flow > 0 {
                        FlowMark(flow: game.flow, calm: session.calm)
                    }
                    Text(Catalog.starName(game.reached))
                        .font(Palette.display(17, italic: false))
                        .foregroundStyle(Palette.chalk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Lives(session: session)
                }
                Spacer(minLength: 0)
            }
            .padding(.trailing, 48)
            .allowsHitTesting(false)
            if let banner = session.banner {
                VStack(alignment: .leading, spacing: 6) {
                    Text(banner.name)
                        .font(Palette.display(30))
                        .foregroundStyle(Palette.chalk)
                    if !banner.rule.isEmpty {
                        Text(banner.rule)
                            .font(Palette.mono(11))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.chalkDim)
                    }
                }
                .padding(.top, 18)
                .transition(.opacity)
                .allowsHitTesting(false)
            }
            Spacer()
            if let hint = session.hint {
                Text(hint)
                    .font(Palette.mono(11, weight: .medium))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.chalk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Palette.scrim.opacity(0.66))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 36)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .overlay(alignment: .topTrailing) {
            PauseButton(session: session)
                .padding(.top, 8)
                .padding(.trailing, 14)
        }
    }
}

private struct FlowMark: View {
    let flow: Int
    let calm: Bool
    @State private var scale: CGFloat = 1

    var body: some View {
        Text("FLOW ×\(1 + flow)")
            .font(Palette.mono(13, weight: .medium))
            .tracking(1.3)
            .foregroundStyle(Palette.comet)
            .scaleEffect(scale, anchor: .leading)
            .onAppear { bump() }
            .onChange(of: flow) { _, _ in bump() }
    }

    private func bump() {
        guard !calm else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { scale = 1.7 }
        withAnimation(.easeOut(duration: 0.35)) { scale = 1 }
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
            let radius = kind == .red ? 9.0 : kind == .blue ? 8.0 : 10.0
            drawGlyph(
                context, x: size.width / 2, y: size.height / 2, size: radius * size.width / 24, kind: kind,
                charted: true, color: tintColor(kind), lineWidth: 1.2
            )
        }
        .frame(width: 24, height: 24)
    }
}

private struct CTA: View {
    let text: String
    let calm: Bool
    @State private var dim = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Palette.comet)
                .frame(width: 8, height: 8)
                .opacity(calm || !dim ? 1 : 0.25)
                .scaleEffect(calm || !dim ? 1 : 0.7)
            Text(text)
                .font(Palette.mono(12, weight: .medium))
                .tracking(1.7)
                .textCase(.uppercase)
                .foregroundStyle(Palette.chalk)
        }
        .onAppear {
            guard !calm else { return }
            withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) { dim = true }
        }
    }
}

private struct TitleCard: View {
    let records: Records
    let calm: Bool

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                Text("Perihelion")
                    .font(Palette.display(min(86, max(54, geo.size.width * 0.17))))
                    .foregroundStyle(Palette.chalk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.trailing, 108)
                Text("Tap to let go of your star. Catch the next one before this one burns out.")
                    .font(Palette.display(20, italic: false))
                    .foregroundStyle(Palette.chalk)
                    .padding(.top, 14)
                    .padding(.trailing, 12)
                Spacer(minLength: 16)
                if geo.size.height >= 600 {
                    VStack(alignment: .leading, spacing: 10) {
                        row(.white, "White stars hold steady.")
                        row(.red, "Red giants swing wide and burn out fast.")
                        row(.blue, "Blue stars spin tight and quick.")
                    }
                }
                Text("Leave on your first lap to build flow.")
                    .font(Palette.mono(11))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.chalkDim)
                    .padding(.top, 18)
                if records.hi > 0 {
                    Text("Best \(Palette.points(records.hi)) points, furthest \(Catalog.starName(records.far))")
                        .font(Palette.mono(11))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.chalkDim)
                        .padding(.top, 10)
                }
                CTA(text: "Tap anywhere to begin", calm: calm)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 22)
            .padding(.top, 76)
            .padding(.bottom, 28)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    private func row(_ kind: StarKind, _ text: String) -> some View {
        HStack(spacing: 10) {
            KeyGlyph(kind: kind)
            Text(text)
                .font(Palette.display(16, italic: false))
                .foregroundStyle(Palette.chalk)
        }
    }
}

private struct GameOverCard: View {
    let session: Session

    var body: some View {
        let game = session.game
        VStack(alignment: .leading, spacing: 14) {
            Text(game.cause)
                .font(Palette.display(40))
                .foregroundStyle(Palette.chalk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 96)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(Palette.points(game.score))
                    .font(Palette.display(72))
                    .foregroundStyle(Palette.chalk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                VStack(alignment: .leading, spacing: 6) {
                    Text("points")
                        .font(Palette.mono(12, weight: .medium))
                        .tracking(1.7)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.chalk)
                    if session.newBest {
                        Text("New best")
                            .font(Palette.mono(12, weight: .medium))
                            .tracking(1.7)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.comet)
                    }
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
                stat("Reached", game.reached > 0 ? "\(Catalog.starName(game.reached)), star \(game.reached)" : "Nowhere past Sol")
                stat("Best flow", "×\(1 + game.stats.bestFlow)")
                stat("Dead centres", "\(game.stats.centres)")
                stat("Best score", Palette.points(session.records.hi))
            }
            .padding(.top, 4)
            CTA(text: "Tap to launch again", calm: session.calm)
                .padding(.top, 10)
        }
        .padding(.horizontal, 22)
        .padding(.top, 76)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func stat(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(key)
                .font(Palette.mono(12))
                .tracking(0.7)
                .textCase(.uppercase)
                .foregroundStyle(Palette.chalkDim)
            Text(value)
                .font(Palette.mono(12))
                .foregroundStyle(Palette.chalk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PauseCard: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Paused")
                .font(Palette.display(44))
                .foregroundStyle(Palette.chalk)
            HStack(spacing: 12) {
                Button("Resume") { session.setPaused(false) }
                    .buttonStyle(ChartButton(primary: true))
                Button("Start over") { session.restart() }
                    .buttonStyle(ChartButton(primary: false))
            }
            Button("Adjust") { session.openSettings() }
                .buttonStyle(ChartButton(primary: false))
        }
        .padding(.horizontal, 22)
        .padding(.top, 76)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SoundControl: View {
    let session: Session

    var body: some View {
        Button {
            session.toggleMuted()
        } label: {
            Text(session.records.muted ? "Sound off" : "Sound on")
        }
        .buttonStyle(ChartButton(primary: false, dashed: session.records.muted, dim: session.records.muted))
        .accessibilityLabel(session.records.muted ? "Sound off" : "Sound on")
    }
}

private struct PauseButton: View {
    let session: Session

    var body: some View {
        Button {
            session.setPaused(true)
        } label: {
            HStack(spacing: 4) {
                Rectangle().frame(width: 4, height: 14)
                Rectangle().frame(width: 4, height: 14)
            }
            .foregroundStyle(Palette.chalk)
            .frame(width: 44, height: 44)
            .overlay(Rectangle().stroke(Palette.chalkDim, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pause")
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
                        .font(Palette.display(16, italic: false))
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
                .font(Palette.display(15, italic: false))
                .foregroundStyle(Palette.chalk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ChartButton: ButtonStyle {
    var primary = false
    var dashed = false
    var dim = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Palette.mono(11, weight: .medium))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(dim ? Palette.chalkDim : (primary ? Palette.comet : Palette.chalk))
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(configuration.isPressed ? Palette.chalk.opacity(0.14) : Palette.scrim.opacity(0.45))
            .overlay {
                let dash: [CGFloat] = dashed ? [3, 3] : []
                Rectangle().stroke(
                    primary ? Palette.comet : (dim ? Palette.chalkDim : Palette.chalk.opacity(0.64)),
                    style: StrokeStyle(lineWidth: 1, dash: dash)
                )
            }
    }
}
