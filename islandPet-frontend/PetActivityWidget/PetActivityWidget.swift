import WidgetKit
import SwiftUI
import UIKit
import ActivityKit
import AppIntents

/// Safely resolve a pet image by name, falling back to a system symbol.
private func petImage(named name: String) -> UIImage {
    UIImage(named: name) ?? UIImage(systemName: "pawprint.fill") ?? UIImage()
}

// A helper view to contain the logic for switching between widget families.
struct PetActivityView: View {
    @Environment(\.activityFamily) var activityFamily
    let context: ActivityViewContext<PetAttributes>

    var body: some View {
        if context.isStale {
            // MARK: - Stale View Layout
            HStack {
                Image(context.attributes.speciesID)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .padding()

                VStack(alignment: .leading) {
                    Text("\(context.attributes.speciesID.capitalized)'s adventure has ended!")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Start a new session in the app.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(Color.gray.opacity(0.5))
            
        } else {
            // MARK: - Active View Layout
            switch activityFamily {
            case .small:
                HStack(spacing: 10) {
                                Image(uiImage: petImage(named: context.attributes.speciesID))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 75, height: 75)

                                VStack(alignment: .leading) {
                                    HStack {
                                        Button(intent: PlayPetIntent(
                                            petID: context.attributes.petID,
                                            hunger: context.state.hunger,
                                            happiness: context.state.happiness,
                                            speciesID: context.attributes.speciesID
                                            )
                                        ) {
                                           Image(systemName: "heart.fill")
                                        }
                                        .tint(happinessColor(for: context.state.happiness).opacity(0.8))

                                        Text("\(context.state.happiness)%")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    HStack {
                                        Button(intent: FeedPetIntent(
                                            petID: context.attributes.petID,
                                            hunger: context.state.hunger,
                                            happiness: context.state.happiness,
                                            speciesID: context.attributes.speciesID
                                            )
                                        ) {
                                            Image(systemName: "fork.knife")
                                        }
                                        .tint(hungerColor(for: context.state.hunger).opacity(0.8))
                                        Text("\(context.state.hunger)%")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
            default:
                HStack(alignment: .center, spacing: 12) {
                    Image(uiImage: petImage(named: context.attributes.speciesID))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(context.attributes.speciesID.capitalized)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.white)
                            if #available(iOS 16.1, *) {
                                Button(intent: PlayPetIntent(
                                    petID: context.attributes.petID,
                                    hunger: context.state.hunger,
                                    happiness: context.state.happiness,
                                    speciesID: context.attributes.speciesID
                                    )
                                ) {
                                    Label("Play", systemImage: "gamecontroller")
                                        .labelStyle(.titleAndIcon)
                                }
                                .font(.subheadline)
                                .tint(happinessColor(for: context.state.happiness))
                                .frame(minWidth: 100)
                            }
                        }
                        .padding(.top, 20)

                        VStack(alignment: .leading, spacing: 4) {
                            statRow(
                                title: "Happiness",
                                value: context.state.happiness,
                                tint: .clear
                            )
                            statRow(
                                title: "Hunger",
                                value: context.state.hunger,
                                tint: .clear
                            )
                        }

                        HStack {
                            Spacer()
                            if #available(iOS 16.1, *) {
                                Button(intent: FeedPetIntent(
                                    petID: context.attributes.petID,
                                    hunger: context.state.hunger,
                                    happiness: context.state.happiness,
                                    speciesID: context.attributes.speciesID
                                    )
                                ) {
                                    Label("Feed", systemImage: "fork.knife")
                                        .labelStyle(.titleAndIcon)
                                }
                                .font(.subheadline)
                                .tint(hungerColor(for: context.state.hunger))
                                .frame(minWidth: 100)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.trailing, 12)
                }
                .activityBackgroundTint(Color.black.opacity(0.45))
                .activitySystemActionForegroundColor(.white)
            }
        }
    }
}



struct PetActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetAttributes.self) { context in
            PetActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(uiImage: petImage(named: context.attributes.speciesID))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .center, spacing: 6) {
                        statRow(
                            title: "Happiness",
                            value: context.state.happiness,
                            tint: .clear,
                            barWidth: 80
                        )
                        statRow(
                            title: "Hunger",
                            value: context.state.hunger,
                            tint: .clear,
                            barWidth: 80
                        )
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(spacing: 8) {
                        if #available(iOS 16.1, *) {
                            Button(intent: PlayPetIntent(petID: context.attributes.petID, hunger: context.state.hunger, happiness: context.state.happiness, speciesID: context.attributes.speciesID)) {
                                Image(systemName: "gamecontroller")
                                    .imageScale(.large)
                            }
                            .tint(happinessColor(for: context.state.happiness))

                            Button(intent: FeedPetIntent(petID: context.attributes.petID, hunger: context.state.hunger, happiness: context.state.happiness, speciesID: context.attributes.speciesID)) {
                                Image(systemName: "fork.knife")
                                    .imageScale(.large)
                            }
                            .tint(hungerColor(for: context.state.hunger))
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Spacer()
                }
            } compactLeading: {
                Image(uiImage: petImage(named: context.attributes.speciesID))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 35, height: 25)
            } compactTrailing: {
            } minimal: {
                Image(uiImage: petImage(named: context.attributes.speciesID))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15)
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

// MARK: – Helper for lock‑screen stats
private func statRow(title: String,
                     value: Int,
                     tint: Color,
                     barWidth: CGFloat? = nil) -> some View {

    let finalTint: Color
    if title == "Hunger" {
        finalTint = hungerColor(for: value)
    } else { // Happiness
        finalTint = happinessColor(for: value)
    }

    return VStack(alignment: .leading, spacing: 2) {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white)
            Spacer(minLength: 4)
            Text("\(value)%")
                .font(.caption2)
                .monospacedDigit()
                .foregroundColor(.white)
        }
        ProgressView(value: Double(value), total: 100)
            .progressViewStyle(.linear)
            .frame(width: barWidth)
            .tint(finalTint)
    }
}
