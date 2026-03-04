import os
import SwiftUI
import ActivityKit
import WidgetKit

struct PetDashboardView: View {
    let pet: Pet
    let onRehome: () -> Void

    // MARK: - State Properties
    @State private var currentActivity: Activity<PetAttributes>?
    @State private var hunger: Int
    @State private var happiness: Int

    // MARK: - AppStorage for Persistence
    @AppStorage("sessionID", store: UserDefaults(suiteName: "group.com.superbailey.IslandPet")) private var storedSessionID: String = ""
    @AppStorage("petID", store: UserDefaults(suiteName: "group.com.superbailey.IslandPet")) private var storedPetID: String = ""
    @AppStorage("lastKnownHunger", store: UserDefaults(suiteName: "group.com.superbailey.IslandPet")) private var lastKnownHunger: Int = 0
    @AppStorage("lastKnownHappiness", store: UserDefaults(suiteName: "group.com.superbailey.IslandPet")) private var lastKnownHappiness: Int = 100
    
    @AppStorage("foodCount", store: UserDefaults(suiteName: "group.com.superbailey.IslandPet")) private var foodCount: Int = 0
    @AppStorage("wormCount", store: UserDefaults(suiteName: "group.com.superbailey.IslandPet")) private var wormCount: Int = 0
    
    @State private var showEndConfirmation: Bool = false
    @State private var showFishingGame: Bool = false
    @State private var showTugOfWarGame: Bool = false

        init(pet: Pet, onRehome: @escaping () -> Void) {
            self.pet = pet
            self.onRehome = onRehome
            
            let userDefaults = UserDefaults(suiteName: "group.com.superbailey.IslandPet")
            let initialHunger = userDefaults?.integer(forKey: "lastKnownHunger") ?? 0
            let initialHappiness = userDefaults?.integer(forKey: "lastKnownHappiness") ?? 100
            
            _hunger = State(initialValue: initialHunger)
            _happiness = State(initialValue: initialHappiness)
        }
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header, Pet Portrait, Stats, and Action Buttons remain the same
                // ...
                 // MARK: – Header
                VStack(spacing: 12) {
                    Text("Island Pet – \(pet.name)")
                        .font(.largeTitle.bold())
                }

                // MARK: – Pet portrait
                Image(pet.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .shadow(radius: 10)

                // MARK: – Stats card
                VStack(spacing: 16) {
                    statRow(title: "Happiness", value: happiness, tint: happinessColor(for: happiness))
                    if happiness <= 5 {
                        Text("Your pet is very sad! Play with it soon!")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.top, -10)
                    }
                    statRow(title: "Hunger", value: hunger, tint: hungerColor(for: hunger))
                    if hunger >= 95 {
                        Text("Your pet is very hungry! Feed it soon!")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, -10)
                    }
                    Divider()
                    HStack {
                        Image(systemName: "fish.fill")
                            .foregroundColor(.cyan)
                        Text("Food")
                            .font(.headline)
                        Spacer()
                        Text("\(foodCount)")
                            .font(.headline)
                            .monospacedDigit()
                    }
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                        Text("Worms")
                            .font(.headline)
                        Spacer()
                        Text("\(wormCount)")
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                // MARK: – Actions
                VStack(spacing: 12) {
                    Button {
                        Task { await startPet() }
                    } label: {
                        Label("Start Live Activity", systemImage: "pawprint")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(currentActivity != nil)

                    HStack(spacing: 20) {
                        actionButton("Feed (\(foodCount))", systemImage: "fork.knife") {
                            Task { await feedPet() }
                        }
                        .tint(hungerColor(for: hunger))
                        .disabled(foodCount <= 0)

                        actionButton("Play", systemImage: "gamecontroller") {
                            showTugOfWarGame = true
                        }
                        .tint(happinessColor(for: happiness))
                    }

                    Button {
                        showFishingGame = true
                    } label: {
                        Label("Go Fishing", systemImage: "fish.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.cyan)

                    Button {
                        Task { await endPet() }
                    } label: {
                        Label("Stop Live Activity", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(currentActivity == nil)
                    
                    Button(role: .destructive) {
                        showEndConfirmation = true
                    } label: {
                        Label("End Pet", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.red)

                }
            }
            .padding(24)
        }
        .refreshable {
            await fetchLatestPetState()
        }
        .task {
            for activity in Activity<PetAttributes>.activities {
                if activity.attributes.petID == pet.id {
                    await MainActor.run { currentActivity = activity }
                    break
                }
            }
            await fetchLatestPetState()
        }
        .onChange(of: currentActivity?.content.state) { _, newState in
            if let state = newState {
                updatePetState(hunger: state.hunger, happiness: state.happiness)
            }
        }
        .task(id: currentActivity?.id) {
            guard let activity = currentActivity else { return }
            for await contentState in activity.contentUpdates {
                let state = contentState.state
                await MainActor.run {
                    updatePetState(hunger: state.hunger, happiness: state.happiness)
                }
            }
        }
        .onReceive(Timer.publish(every: 600.0, on: .main, in: .common).autoconnect()) { _ in
            Task {
                if currentActivity == nil {
                    await fetchLatestPetState()
                }
            }
        }
        .alert("End Pet?", isPresented: $showEndConfirmation) {
            Button("End Pet", role: .destructive) { Task { await endPetCompletely() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently remove this pet? This cannot be undone.")
        }
        .sheet(isPresented: $showFishingGame) {
            FishingGameView(petAssetName: pet.assetName)
        }
        .sheet(isPresented: $showTugOfWarGame) {
            TugOfWarGameView(petAssetName: pet.assetName) { reward in
                Task {
                    await applyHappinessReward(reward)
                }
            }
        }
    }

    @ViewBuilder
    private func statRow(title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(value)%")
                    .monospacedDigit()
            }
            ProgressView(value: Double(value), total: 100)
                .tint(tint)
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

// MARK: – Network and Activity Helpers
extension PetDashboardView {

    // NEW: Centralized function to update both @State and @AppStorage
    private func updatePetState(hunger: Int, happiness: Int) {
        self.hunger = hunger
        self.happiness = happiness
        self.lastKnownHunger = hunger
        self.lastKnownHappiness = happiness
        print("🔄 Pet state updated and persisted: Hunger \(hunger), Happiness \(happiness)")
    }

    private func fetchLatestPetState() async {
        print("⏰ Fetching latest pet state from server...")
        do {
            let resp = try await Network.fetchPetState(petID: pet.id)
            await MainActor.run {
                updatePetState(hunger: resp.hunger, happiness: resp.happiness)
            }
        } catch {
            print("❌ fetchLatestPetState error:", error)
        }
    }

    @MainActor
    private func startPet() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attrs = PetAttributes(petID: pet.id, speciesID: pet.assetName)
        let contentState = PetAttributes.ContentState(happiness: happiness, hunger: hunger)
        let content = ActivityContent(state: contentState, staleDate: nil)

        do {
            let activity = try Activity.request(attributes: attrs, content: content, pushType: .token)
            currentActivity = activity
            
            let activityIDString = String(describing: activity.id)
            let isNewSession = storedSessionID.isEmpty || storedSessionID != activityIDString
            let newID = String(describing: activity.id)

            Task.detached {
                var first = true
                for await tokenData in activity.pushTokenUpdates {
                    do {
                        if first {
                            if isNewSession {
                                try await Network.registerPetSession(activityID: activity.id, token: tokenData.map { String(format: "%02x", $0) }.joined(), petID: pet.id, speciesID: pet.assetName)
                            } else {
                                try await Network.updateSessionActivityID(oldActivityID: storedSessionID, newActivityID: activity.id)
                            }
                            await MainActor.run { storedSessionID = newID }
                            first = false
                        } else {
                            try await Network.sendLiveActivityToken(tokenData, activityID: activity.id, petID: pet.id, speciesID: pet.assetName)
                        }
                    } catch {
                        print("❌ session registration/update error:", error)
                    }
                }
            }
        } catch {
            print("❌ Activity.request failed:", error)
        }
    }

    private func feedPet() async {
        guard foodCount > 0 else { return }
        foodCount -= 1
        os_log("🍖 Feeding pet")
        let newHunger    = max(0, hunger - 25)
        let newHappiness = happiness

        if let activity = currentActivity {
            var state = activity.content.state
            state.hunger = newHunger
            await activity.update(using: state)
        }

        Task.detached {
            do {
                try await Network.sendPetStateUpdate(petID: pet.id, hunger: newHunger, happiness: newHappiness)
            } catch {
                print("❌ sendPetStateUpdate error:", error)
            }
        }

        await MainActor.run {
            updatePetState(hunger: newHunger, happiness: newHappiness)
        }
    }

    private func applyHappinessReward(_ amount: Int) async {
        os_log("🎮 Playing mini-game with pet, reward: %{public}d", amount)
        let newHunger    = hunger
        let newHappiness = min(100, happiness + max(0, amount))

        if let activity = currentActivity {
            var state = activity.content.state
            state.happiness = newHappiness
            await activity.update(using: state)
        }

        Task.detached {
            do {
                try await Network.sendPetStateUpdate(petID: pet.id, hunger: newHunger, happiness: newHappiness)
            } catch {
                print("❌ sendPetStateUpdate error:", error)
            }
        }

        await MainActor.run {
            updatePetState(hunger: newHunger, happiness: newHappiness)
        }
    }

    private func endPet() async {
        os_log("🛑 Ending Live Activity")
        guard let activity = currentActivity else { return }
        await activity.end(dismissalPolicy: .immediate)
        currentActivity = nil
    }
    
    @MainActor
    private func endPetCompletely() async {
        if let activity = currentActivity {
            do {
                try await Network.sendEndActivity(activityID: activity.id)
            } catch {
                print("❌ sendEndActivity error:", error)
            }
            await activity.end(dismissalPolicy: .immediate)
            currentActivity = nil
        }
        do {
            try await Network.endPetCompletely(petID: pet.id)
        } catch {
            print("❌ clearAllData error:", error)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "PetStatusWidget")
        onRehome()
    }
}
