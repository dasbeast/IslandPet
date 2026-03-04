import SwiftUI
import UIKit

// MARK: - Game State Machine
enum FishingState {
    case idle
    case casting
    case waiting
    case biting
    case result
}

// MARK: - Ocean Canvas (draws water + waves every frame)
struct OceanView: View {
    var time: Double
    var waterTop: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            
            // Only draw below waterTop
            guard waterTop < h else { return }
            
            // Deep water fill
            let waterRect = CGRect(x: 0, y: waterTop, width: w, height: h - waterTop)
            context.fill(
                Path(waterRect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.12, green: 0.42, blue: 0.72),
                        Color(red: 0.05, green: 0.22, blue: 0.48)
                    ]),
                    startPoint: CGPoint(x: w / 2, y: waterTop),
                    endPoint: CGPoint(x: w / 2, y: h)
                )
            )
            
            // Draw multiple wave layers back to front
            let waveLayers: [(speed: Double, amp: CGFloat, freq: CGFloat, yOffset: CGFloat, color: Color)] = [
                (0.3,  12, 1.2, 10, Color(red: 0.08, green: 0.32, blue: 0.60).opacity(0.6)),
                (0.5,  10, 1.8,  4, Color(red: 0.16, green: 0.46, blue: 0.76).opacity(0.7)),
                (0.8,   8, 2.4,  0, Color(red: 0.22, green: 0.54, blue: 0.84).opacity(0.6)),
                (1.2,   5, 3.2,  2, Color(red: 0.35, green: 0.62, blue: 0.90).opacity(0.4)),
                (1.6,   3, 4.5,  0, Color.white.opacity(0.22)),
            ]
            
            for layer in waveLayers {
                let phase = CGFloat(time * layer.speed)
                var wavePath = Path()
                let waveY = waterTop + layer.yOffset
                
                wavePath.move(to: CGPoint(x: 0, y: h))
                wavePath.addLine(to: CGPoint(x: 0, y: waveY))
                
                let step: CGFloat = 3
                var x: CGFloat = 0
                while x <= w {
                    let norm = x / w
                    let primary = sin((norm * layer.freq + phase) * .pi * 2) * layer.amp
                    let secondary = sin((norm * layer.freq * 2.1 + phase * 1.4) * .pi * 2) * (layer.amp * 0.25)
                    let y = waveY + primary + secondary
                    wavePath.addLine(to: CGPoint(x: x, y: y))
                    x += step
                }
                
                wavePath.addLine(to: CGPoint(x: w, y: h))
                wavePath.closeSubpath()
                
                context.fill(wavePath, with: .color(layer.color))
            }
            
            // Foam dots near waterline around dock area
            let foamCount = 12
            for i in 0..<foamCount {
                let t = CGFloat(i) / CGFloat(foamCount)
                let phase = sin((t * 4.0 + CGFloat(time) * 1.3) * .pi * 2)
                let fx = w * (0.05 + t * 0.9)
                let fy = waterTop + 2 + phase * 5
                let radius = 2.0 + abs(phase) * 2.5
                let foamRect = CGRect(x: fx - radius, y: fy - radius,
                                      width: radius * 2, height: radius * 2)
                context.opacity = 0.3 + abs(phase) * 0.4
                context.fill(Ellipse().path(in: foamRect), with: .color(.white))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Floating Score Text
struct FloatingScore: View {
    let amount: Int
    @State private var floatUp = false
    @State private var fadeOut = false

    var body: some View {
        Text("+\(amount)")
            .font(.title.bold())
            .foregroundStyle(.yellow)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            .offset(y: floatUp ? -60 : 0)
            .opacity(fadeOut ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) {
                    floatUp = true
                }
                withAnimation(.easeOut(duration: 1.2).delay(0.4)) {
                    fadeOut = true
                }
            }
    }
}

// MARK: - Ripple Effect
struct RippleView: View {
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0.8

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(opacity), lineWidth: 2)
            .frame(width: 50, height: 50)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    scale = 2.0
                    opacity = 0
                }
            }
    }
}

// MARK: - Main Fishing Game View
struct FishingGameView: View {
    let petAssetName: String
    @Environment(\.dismiss) private var dismiss

    @AppStorage("foodCount", store: UserDefaults(suiteName: "group.com.superbailey.IslandPet"))
    private var foodCount: Int = 0
    @AppStorage("wormCount", store: UserDefaults(suiteName: "group.com.superbailey.IslandPet"))
    private var wormCount: Int = 0

    // Game state
    @State private var gameState: FishingState = .idle
    @State private var biteTime: Date? = nil
    @State private var resultMessage: String = ""
    @State private var lastCatchAmount: Int = 0
    @State private var sessionCatch: Int = 0
    @State private var showFloatingScore: Bool = false

    // Animation state
    @State private var bobberDip: CGFloat = 0
    @State private var bobberVisible: Bool = false
    @State private var lineLength: CGFloat = 0
    @State private var showRipple: Bool = false
    @State private var castBobberOffset: CGFloat = -100

    // Timing task handle
    @State private var waitTask: Task<Void, Never>? = nil
    @State private var activeRoundID: UUID? = nil
    @State private var castHapticTask: Task<Void, Never>? = nil
    @State private var biteHapticTask: Task<Void, Never>? = nil

    // Layout constants
    private let dockWidth: CGFloat = 240
    private let dockHeight: CGFloat = 30
    private let dockPostHeight: CGFloat = 70
    private let waterTopRatio: CGFloat = 0.62

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate

            GeometryReader { geo in
                let waterTop = geo.size.height * waterTopRatio
                let dockY = waterTop + 15
                let dockCenterX = geo.size.width * 0.27
                let lineAnchor = CGPoint(x: dockCenterX + 38, y: dockY - 26)
                // Bobber bobs on the waves
                let bobberBob = CGFloat(sin(time * 2.5)) * 6

                ZStack {
                    // MARK: - Sky
                    LinearGradient(
                        colors: [Color(red: 0.53, green: 0.81, blue: 0.98),
                                 Color(red: 0.28, green: 0.63, blue: 0.90)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    // MARK: - Water + Waves (Canvas-drawn)
                    OceanView(time: time, waterTop: waterTop)

                    // MARK: - Dock
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.55, green: 0.35, blue: 0.18),
                                             Color(red: 0.45, green: 0.28, blue: 0.14)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: dockWidth, height: dockHeight)

                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(red: 0.65, green: 0.42, blue: 0.22).opacity(0.3))
                            .frame(width: dockWidth - 16, height: 8)
                            .offset(y: -7)

                        HStack(spacing: 35) {
                            ForEach(0..<5) { _ in
                                Rectangle()
                                    .fill(Color(red: 0.35, green: 0.22, blue: 0.10).opacity(0.5))
                                    .frame(width: 2, height: dockHeight - 4)
                            }
                        }

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.25))
                            .frame(width: dockWidth - 10, height: 4)
                            .offset(y: 10)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 60) {
                            ForEach(0..<3) { index in
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.48, green: 0.30, blue: 0.14),
                                                     Color(red: 0.38, green: 0.24, blue: 0.11)],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 14, height: dockPostHeight - CGFloat(index * 8))
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 0)
                            }
                        }
                        .offset(y: dockPostHeight * 0.5 + 2)
                    }
                    .position(x: dockCenterX, y: dockY)

                    // MARK: - Pet on dock
                    Image(petAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        .position(x: dockCenterX - 20, y: dockY - 42)

                    // MARK: - Fishing line + bobber
                    if bobberVisible {
                        let bobberX = geo.size.width * 0.65
                        let bobberY = waterTop + bobberDip + bobberBob

                        Path { path in
                            path.move(to: lineAnchor)
                            path.addQuadCurve(
                                to: CGPoint(x: bobberX, y: bobberY + castBobberOffset),
                                control: CGPoint(x: (lineAnchor.x + bobberX) / 2, y: lineAnchor.y - 20)
                            )
                        }
                        .stroke(Color.brown.opacity(0.7), lineWidth: 2)

                        if showRipple {
                            RippleView()
                                .position(x: bobberX, y: bobberY)
                        }

                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 20, height: 20)
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.red, .red.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 20, height: 20)
                                .offset(y: -5)
                                .clipShape(
                                    Rectangle()
                                        .size(width: 20, height: 10)
                                        .offset(y: -5)
                                )

                            Circle()
                                .fill(.white.opacity(0.4))
                                .frame(width: 6, height: 6)
                                .offset(x: -3, y: -6)
                        }
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                        .rotationEffect(.degrees(Double(bobberBob) * 1.5))
                        .position(x: bobberX, y: bobberY)
                        .offset(y: castBobberOffset)
                    }

                    // MARK: - Floating score
                    if showFloatingScore && lastCatchAmount > 0 {
                        FloatingScore(amount: lastCatchAmount)
                            .position(x: geo.size.width * 0.65, y: waterTop)
                    }

                    // MARK: - UI Overlay
                    VStack {
                        HStack {
                            Button {
                                waitTask?.cancel()
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.9))
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Image(systemName: "leaf.fill")
                                    .foregroundStyle(.green)
                                Text("\(wormCount)")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())

                            HStack(spacing: 6) {
                                Image(systemName: "fish.fill")
                                    .foregroundStyle(.yellow)
                                Text("\(foodCount)")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                        Spacer()

                        Text(statusMessage)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                            .padding(.bottom, 8)
                            .animation(.easeInOut(duration: 0.3), value: gameState)

                        if gameState == .result && !resultMessage.isEmpty {
                            Text(resultMessage)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .transition(.opacity)
                                .padding(.bottom, 4)
                        }

                        Button {
                            handleTap()
                        } label: {
                            Text(buttonLabel)
                                .font(.title2.bold())
                                .frame(maxWidth: 260)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(buttonTint)
                        .controlSize(.large)
                        .disabled(gameState == .casting)
                        .padding(.bottom, 8)
                        .scaleEffect(gameState == .biting ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: gameState)

                        Button {
                            wormCount += 1
                        } label: {
                            Text("Find Worm (+1)")
                                .font(.headline)
                                .frame(maxWidth: 220)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        .padding(.bottom, 4)

                        Text("Session: \(sessionCatch) fish caught")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.bottom, 20)
                    }
                }
            }
        }
        .onDisappear {
            waitTask?.cancel()
            cancelAllHaptics()
        }
    }

    // MARK: - Computed Properties

    private var statusMessage: String {
        switch gameState {
        case .idle:
            if wormCount <= 0 {
                return "No worms left. Find one to cast."
            }
            return "Tap Cast to start fishing!"
        case .casting:
            return "Casting..."
        case .waiting:
            return "Waiting for a bite..."
        case .biting:
            return "A fish! Reel it in!"
        case .result:
            return resultMessage
        }
    }

    private var buttonLabel: String {
        switch gameState {
        case .idle: return "Cast"
        case .casting: return "Casting..."
        case .waiting: return "Waiting..."
        case .biting: return "REEL!"
        case .result: return "Cast Again"
        }
    }

    private var buttonTint: Color {
        switch gameState {
        case .idle:
            return wormCount > 0 ? .cyan : .gray
        case .casting:
            return .cyan
        case .waiting: return .gray
        case .biting: return .orange
        case .result: return lastCatchAmount > 0 ? .green : .red
        }
    }

    // MARK: - Game Logic

    private func handleTap() {
        switch gameState {
        case .idle:
            startCast()
        case .waiting:
            // Tapped too early
            tooEarly()
        case .biting:
            reelIn()
        case .result:
            resetCast()
        default:
            break
        }
    }

    private func startCast() {
        guard gameState == .idle else { return }
        guard wormCount > 0 else {
            resultMessage = "No worms left. Find more bait first."
            warningHaptic()
            return
        }
        cancelWaitTask()
        cancelAllHaptics()
        let roundID = UUID()
        activeRoundID = roundID
        wormCount -= 1

        gameState = .casting
        bobberVisible = true
        castBobberOffset = -100
        bobberDip = 0
        showRipple = false
        showFloatingScore = false
        biteTime = nil
        resultMessage = ""

        // Animate the cast
        withAnimation(.easeOut(duration: 0.5)) {
            castBobberOffset = 0
        }
        startCastHapticCountdown()

        // Transition to waiting after cast animation
        waitTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s for cast animation
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard activeRoundID == roundID, gameState == .casting else { return }
                gameState = .waiting
            }

            // Random wait before fish bites
            let waitSeconds = Double.random(in: 1.5...4.0)
            try? await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }

            // Fish is biting!
            await MainActor.run {
                guard activeRoundID == roundID, gameState == .waiting else { return }
                biteTime = Date()
                gameState = .biting
                showRipple = true
                startBiteAlertHaptics()
                withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                    bobberDip = 18
                }
            }

            // Timeout: if player doesn't tap within 1.2s
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard activeRoundID == roundID else { return }
                if gameState == .biting {
                    tooLate()
                }
            }
        }
    }

    private func tooEarly() {
        cancelWaitTask()
        cancelAllHaptics()
        warningHaptic()
        lastCatchAmount = 0
        resultMessage = "Too early! The fish got away."
        showResult()
    }

    private func tooLate() {
        cancelWaitTask()
        cancelAllHaptics()
        warningHaptic()
        lastCatchAmount = 0
        resultMessage = "Too slow! The fish escaped."
        showResult()
    }

    private func reelIn() {
        cancelWaitTask()
        cancelAllHaptics()
        guard let bite = biteTime else { return }

        let reaction = Date().timeIntervalSince(bite)

        if reaction < 0.4 {
            lastCatchAmount = 3
            resultMessage = "Amazing catch! +3"
        } else if reaction < 0.8 {
            lastCatchAmount = 2
            resultMessage = "Nice catch! +2"
        } else {
            lastCatchAmount = 1
            resultMessage = "Just barely! +1"
        }

        foodCount += lastCatchAmount
        sessionCatch += lastCatchAmount
        showFloatingScore = true
        successHaptic()
        showResult()
    }

    private func showResult() {
        cancelWaitTask()
        cancelAllHaptics()
        gameState = .result
        showRipple = false
        activeRoundID = nil

        withAnimation(.spring(response: 0.3)) {
            bobberDip = 0
        }
    }

    private func resetCast() {
        cancelAllHaptics()
        gameState = .idle
        bobberVisible = false
        bobberDip = 0
        showRipple = false
        showFloatingScore = false
        biteTime = nil
        castBobberOffset = -100
        activeRoundID = nil
        waitTask = nil
    }

    private func cancelWaitTask() {
        waitTask?.cancel()
        waitTask = nil
    }

    private func startCastHapticCountdown() {
        castHapticTask?.cancel()
        castHapticTask = Task {
            for _ in 0..<4 {
                guard !Task.isCancelled else { return }
                let state = await MainActor.run { gameState }
                guard state == .casting || state == .waiting else { return }
                castPulseHaptic()
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }

    private func startBiteAlertHaptics() {
        biteHapticTask?.cancel()
        biteHapticTask = Task {
            while !Task.isCancelled {
                let state = await MainActor.run { gameState }
                guard state == .biting else { return }
                bitePulseHaptic()
                try? await Task.sleep(nanoseconds: 170_000_000)
                guard !Task.isCancelled else { return }
                bitePulseHaptic()
                try? await Task.sleep(nanoseconds: 170_000_000)
                guard !Task.isCancelled else { return }
                bitePulseHaptic()
                try? await Task.sleep(nanoseconds: 380_000_000)
            }
        }
    }

    private func cancelAllHaptics() {
        castHapticTask?.cancel()
        castHapticTask = nil
        biteHapticTask?.cancel()
        biteHapticTask = nil
    }

    @MainActor
    private func castPulseHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.55)
    }

    @MainActor
    private func bitePulseHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }

    @MainActor
    private func warningHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    @MainActor
    private func successHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

#Preview {
    FishingGameView(petAssetName: "winnie")
}
