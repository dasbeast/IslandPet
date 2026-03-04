import SwiftUI
import UIKit

enum TugDirection {
    case left
    case right
}

struct TugOfWarGameView: View {
    let petAssetName: String
    let onComplete: (_ happinessReward: Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var ropePosition: Double = 0
    @State private var timeRemaining: Double = 8.0
    @State private var gameStarted: Bool = false
    @State private var gameFinished: Bool = false
    @State private var resultTitle: String = ""
    @State private var resultDetail: String = ""
    @State private var reward: Int = 0
    @State private var lastPullDirection: TugDirection? = nil
    @State private var lastPullAt: Date = .now

    @State private var gameTask: Task<Void, Never>? = nil

    private let winThreshold: Double = 130
    private let loseThreshold: Double = -130

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.85, blue: 0.70),
                        Color(red: 0.94, green: 0.68, blue: 0.46)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    HStack {
                        Button {
                            stopGameTask()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        Spacer()

                        Text("\(timeRemaining, specifier: "%.1f")s")
                            .font(.title3.bold())
                            .monospacedDigit()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Text("Tug of War")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)

                    HStack(spacing: 26) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(.white)

                        Image(petAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 132, height: 132)
                            .shadow(radius: 4)
                    }

                    VStack(spacing: 12) {
                        ZStack {
                            Capsule()
                                .fill(Color.black.opacity(0.20))
                                .frame(height: 22)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.brown.opacity(0.95), .orange.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 14)

                            Rectangle()
                                .fill(.white.opacity(0.9))
                                .frame(width: 4, height: 34)

                            Circle()
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                                .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
                                .offset(x: markerXOffset(totalWidth: geo.size.width - 60))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 30)

                        HStack {
                            Text("YOU")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                            Spacer()
                            Text("PET")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 30)
                    }

                    if gameFinished {
                        VStack(spacing: 6) {
                            Text(resultTitle)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text(resultDetail)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.top, 4)
                    } else {
                        Text("Alternate left and right pulls for max power")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    HStack(spacing: 14) {
                        Button {
                            pull(.left)
                        } label: {
                            Label("Pull Left", systemImage: "arrow.left.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(!gameStarted || gameFinished)

                        Button {
                            pull(.right)
                        } label: {
                            Label("Pull Right", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(!gameStarted || gameFinished)
                    }
                    .padding(.horizontal, 20)

                    Button {
                        if gameFinished {
                            dismiss()
                        } else {
                            startGame()
                        }
                    } label: {
                        Text(gameFinished ? "Done" : (gameStarted ? "Playing..." : "Start Tug"))
                            .font(.title3.bold())
                            .frame(maxWidth: 260)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(gameFinished ? .green : .orange)
                    .disabled(gameStarted && !gameFinished)

                    Spacer(minLength: 12)
                }
            }
        }
        .onDisappear {
            stopGameTask()
        }
    }

    private func markerXOffset(totalWidth: CGFloat) -> CGFloat {
        let clamped = max(loseThreshold, min(winThreshold, ropePosition))
        let fraction = clamped / winThreshold
        return CGFloat(fraction) * (totalWidth / 2)
    }

    private func startGame() {
        stopGameTask()
        ropePosition = 0
        timeRemaining = 8.0
        gameStarted = true
        gameFinished = false
        resultTitle = ""
        resultDetail = ""
        reward = 0
        lastPullDirection = nil
        lastPullAt = .now

        gameTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard gameStarted, !gameFinished else { return }

                    // Pet always pulls back; if player pauses tapping, the pull surges hard.
                    let secondsSincePull = Date().timeIntervalSince(lastPullAt)
                    if secondsSincePull > 0.25 {
                        ropePosition -= Double.random(in: 6.2...7.4)
                    } else {
                        ropePosition -= Double.random(in: 2.2...3.2)
                    }
                    timeRemaining = max(0, timeRemaining - 0.1)

                    if ropePosition >= winThreshold {
                        finishGame(win: true)
                        return
                    }

                    if ropePosition <= loseThreshold {
                        finishGame(win: false)
                        return
                    }

                    if timeRemaining <= 0 {
                        if ropePosition >= 80 {
                            finishGame(win: true)
                        } else if ropePosition >= 25 {
                            finishGame(draw: true)
                        } else {
                            finishGame(win: false)
                        }
                    }
                }
            }
        }
    }

    private func pull(_ direction: TugDirection) {
        guard gameStarted, !gameFinished else { return }

        let basePower: Double = 5.2
        let bonus: Double = (lastPullDirection != direction) ? 2.2 : -1.6
        let pullAmount = max(2.6, basePower + bonus)
        ropePosition += pullAmount
        lastPullDirection = direction
        lastPullAt = .now

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.9)

        if ropePosition >= winThreshold {
            finishGame(win: true)
        }
    }

    private func finishGame(win: Bool = false, draw: Bool = false) {
        guard !gameFinished else { return }

        gameFinished = true
        gameStarted = false
        stopGameTask()

        if win {
            reward = 20
            resultTitle = "You Win!"
            resultDetail = "Your pet had a blast. +20 happiness"
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        } else if draw {
            reward = 10
            resultTitle = "Close Match!"
            resultDetail = "Great effort. +10 happiness"
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        } else {
            reward = 3
            resultTitle = "Pet Wins!"
            resultDetail = "Still fun together. +3 happiness"
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
        }

        onComplete(reward)
    }

    private func stopGameTask() {
        gameTask?.cancel()
        gameTask = nil
    }
}

#Preview {
    TugOfWarGameView(petAssetName: "winnie") { _ in }
}
