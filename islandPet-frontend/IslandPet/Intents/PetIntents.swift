//
//  FeedPetIntent.swift
//  IslandPet
//
//  Created by Bailey Kiehl on 5/27/25.
//

import OSLog
import AppIntents
import ActivityKit
import Foundation
import SwiftUI   // for LocalizedStringResource

private let intentLog = Logger(subsystem: "com.superbailey.IslandPet",
                               category: "PetIntents")

/// "Feed" button background intent
@available(iOS 17.0, *)
struct FeedPetIntent: LiveActivityIntent, AppIntent {
    static var title: LocalizedStringResource = "Feed Pet"
    static var description: LocalizedStringResource = "Feed your virtual pet."
   
    @Parameter(title: "Pet ID")
    var petID: String
    
    @Parameter(title: "Current Hunger")
    var hunger: Int
    
    @Parameter(title: "Current Happiness")
    var happiness: Int

    @Parameter(title: "Species ID")
    var speciesID: String
    
    init() {
        self.petID = "invalid pet id"
        self.hunger = 0
        self.happiness = 0
        self.speciesID = ""
    }
    
    init(petID: String, hunger: Int, happiness: Int, speciesID: String) {
        self.petID = petID
        self.hunger = hunger
        self.happiness = happiness
        self.speciesID = speciesID
    }

        // Default initializer (required if you provide a custom one)
    

    func perform() async throws -> some IntentResult  & ReturnsValue<String> {
        intentLog.info("🍖 FeedPetIntent fired")

                // 0. Check food inventory.
                let defaults = UserDefaults(suiteName: "group.com.superbailey.IslandPet")
                let currentFood = defaults?.integer(forKey: "foodCount") ?? 0
                guard currentFood > 0 else {
                    intentLog.info("No food available for feeding")
                    return .result(value: "No food! Open the app to go fishing.")
                }
                defaults?.set(currentFood - 1, forKey: "foodCount")

                // 1. Find the Live Activity first.
                guard let activity = Activity<PetAttributes>.activities.first(where: { $0.attributes.petID == petID }) else {
                    intentLog.error("No Live Activity matching ID: \(self.petID, privacy: .public)")
                    return .result(value: "error feeding")
                }

                // 2. Calculate the new state.
                let newHunger = max(0, activity.content.state.hunger - 20)
                let newHappiness = activity.content.state.happiness
                let newState = PetAttributes.ContentState(happiness: newHappiness, hunger: newHunger)

                // 3. Update the Live Activity UI immediately for a responsive feel.
                await activity.update(using: newState)
                intentLog.info("UI updated instantly for petID: \(self.petID, privacy: .public)")

                // 4. Send the network update directly.
                do {
                    try await Network.sendPetStateUpdate(
                        petID: self.petID,
                        hunger: newHunger,
                        happiness: newHappiness
                    )
                    intentLog.info("Network update sent for petID: \(self.petID, privacy: .public)")
                } catch {
                    intentLog.error("sendPetStateUpdate error: \(error.localizedDescription, privacy: .public)")
                }

        return .result(value: "Pet fed.")
    }
}

/// “Play” button background intent
@available(iOS 17.0, *)
struct PlayPetIntent: LiveActivityIntent, AppIntent {
    
    static var title: LocalizedStringResource = "Play with Pet"
    static var openAppWhenRun: Bool = false
    static var description: LocalizedStringResource = "Play with your virtual pet to increase its happiness."

    @Parameter(title: "Pet ID")
    var petID: String
    
    @Parameter(title: "Current Hunger")
    var hunger: Int
    
    @Parameter(title: "Current Happiness")
    var happiness: Int

    @Parameter(title: "Species ID")
    var speciesID: String

    init(petID: String, hunger: Int, happiness: Int, speciesID: String) {
        self.petID = petID
        self.hunger = hunger
        self.happiness = happiness
        self.speciesID = speciesID
    }

    // Default initializer (required if you provide a custom one)
    init() {
        self.petID = "invalid pet id"
        self.hunger = 0
        self.happiness = 0
        self.speciesID = ""
    }
    

    func perform() async throws -> some IntentResult  & ReturnsValue<String> {
        intentLog.info("🎮 PlayPetIntent fired ")

                // 1. Find the Live Activity first.
                guard let activity = Activity<PetAttributes>.activities.first(where: { $0.attributes.petID == petID }) else {
                    intentLog.error("No Live Activity matching ID: \(self.petID, privacy: .public)")
                    return .result(value: "Error playing")
                }

                // 2. Calculate the new state.
                let newHunger = activity.content.state.hunger
                let newHappiness = min(100, activity.content.state.happiness + 20)
                let newState = PetAttributes.ContentState(happiness: newHappiness, hunger: newHunger)
                
                // 3. Update the Live Activity UI immediately.
                await activity.update(using: newState)
                intentLog.info("UI updated instantly for petID: \(self.petID, privacy: .public)")

                // 4. Send the network update directly.
                do {
                    try await Network.sendPetStateUpdate(
                        petID: self.petID,
                        hunger: newHunger,
                        happiness: newHappiness
                    )
                    intentLog.info("Network update sent for petID: \(self.petID, privacy: .public)")
                } catch {
                    intentLog.error("sendPetStateUpdate error: \(error.localizedDescription, privacy: .public)")
                }

        return .result(value: "Played with pet.")
    }
}
