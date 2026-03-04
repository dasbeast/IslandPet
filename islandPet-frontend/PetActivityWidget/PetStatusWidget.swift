import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct PetStatusEntry: TimelineEntry {
    let date: Date
    let petID: String
    let speciesID: String
    let happiness: Int
    let hunger: Int
}

struct PetStatusProvider: TimelineProvider {
    private static let defaults = UserDefaults(suiteName: "group.com.superbailey.IslandPet")

    private var storedPetID: String {
        Self.defaults?.string(forKey: "petID") ?? ""
    }

    private var storedSpeciesID: String {
        Self.defaults?.string(forKey: "speciesID") ?? ""
    }

    func placeholder(in context: Context) -> PetStatusEntry {
        PetStatusEntry(date: Date(), petID: "winnie", speciesID: "winnie", happiness: 100, hunger: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (PetStatusEntry) -> ()) {
        let entry = PetStatusEntry(date: Date(), petID: storedPetID, speciesID: storedSpeciesID, happiness: 100, hunger: 0)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            guard !storedPetID.isEmpty, !storedSpeciesID.isEmpty else {
                let entry = PetStatusEntry(date: Date(), petID: "", speciesID: "", happiness: 0, hunger: 0)
                let timeline = Timeline(entries: [entry], policy: .atEnd)
                completion(timeline)
                return
            }

            do {
                let petState = try await Network.fetchPetState(petID: storedPetID)
                let entry = PetStatusEntry(
                    date: Date(),
                    petID: storedPetID,
                    speciesID: storedSpeciesID,
                    happiness: petState.happiness,
                    hunger: petState.hunger
                )

                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)

            } catch {
                let entry = PetStatusEntry(date: Date(), petID: storedPetID, speciesID: storedSpeciesID, happiness: 0, hunger: 0)
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            }
        }
    }
}


// 3. The SwiftUI view for the widget
struct PetStatusWidgetView: View {
    // This tells the view what size it's being drawn in
    @Environment(\.widgetFamily) var family
    var entry: PetStatusProvider.Entry

    // Helper view for stat rows
    @ViewBuilder
    private func statRow(title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white)
                Spacer()
                Text("\(value)%")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            ProgressView(value: Double(value), total: 100)
                .tint(tint)
        }
    }

    // The main view now switches based on the family
    @ViewBuilder
    var body: some View {
        if entry.petID.isEmpty {
            Text("Adopt a pet in the app to see it here!")
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .containerBackground(for: .widget) { Color.black.opacity(0.8) }
        } else {
            switch family {
            case .systemSmall:
                // MARK: - Small Widget View
                VStack(spacing: 4) {
                    Text(entry.speciesID.capitalized)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    
                    Image(entry.speciesID)
                        .resizable()
                        .scaledToFit()
                    
                    statRow(title: "Happiness", value: entry.happiness, tint: happinessColor(for: entry.happiness))
                    statRow(title: "Hunger", value: entry.hunger, tint: hungerColor(for: entry.hunger))
                }
                .padding()
                .containerBackground(for: .widget) { Color.black.opacity(0.8) }

            default:
                // MARK: - Medium Widget View
                HStack(alignment: .center, spacing: 12) {
                    Image(entry.speciesID)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.speciesID.capitalized)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .center)

                        VStack(alignment: .leading, spacing: 4) {
                            statRow(
                                title: "Happiness",
                                value: entry.happiness,
                                tint: happinessColor(for: entry.happiness)
                            )
                            statRow(
                                title: "Hunger",
                                value: entry.hunger,
                                tint: hungerColor(for: entry.hunger)
                            )
                        }
                    }
                    .padding(.trailing, 12)
                }
                .padding()
                .containerBackground(for: .widget) { Color.black.opacity(0.8) }
            }
        }
    }
}

// 4. The main widget configuration
struct PetStatusWidget: Widget {
    let kind: String = "PetStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetStatusProvider()) { entry in
            PetStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("My Pet Status")
        .description("Check on your pet's happiness and hunger.")
        .supportedFamilies([.systemSmall, .systemMedium]) // You declare all supported sizes here
    }
}
