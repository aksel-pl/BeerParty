//
//  ProfileSetupView.swift
//  BeerParty
//
//  Created by Codex on 2/11/26.
//
import SwiftUI
import Supabase

struct ProfileSetupView: View {
  @EnvironmentObject var authVM: AuthViewModel

  @State private var weightText: String = ""
  @State private var ageText: String = ""
  @State private var gender: String = ""

  @State private var message: String = ""
  @State private var isLoading: Bool = false

  private let genderOptions = [
    "Male",
    "Female",
    "Non-binary",
    "Prefer not to say"
  ]

  var body: some View {
    NavigationStack {
      Form {
        Section("Profile") {
          TextField("Weight (lbs)", text: $weightText)
            .keyboardType(.decimalPad)

          TextField("Age", text: $ageText)
            .keyboardType(.numberPad)

          Picker("Gender", selection: $gender) {
            ForEach(genderOptions, id: \.self) { option in
              Text(option)
            }
          }
        }

        if !message.isEmpty {
          Section {
            Text(message)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        Section {
          Button(isLoading ? "Saving..." : "Save Profile") {
            Task { await saveProfile() }
          }
          .disabled(isLoading || !canSubmit)
        }
      }
      .navigationTitle("Your Profile")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        if gender.isEmpty {
          gender = genderOptions.first ?? ""
        }
      }
    }
  }

  private var canSubmit: Bool {
    guard let weight = Double(weightText), weight > 0 else { return false }
    guard let age = Int(ageText), age > 0 else { return false }
    return !gender.isEmpty
  }

  @MainActor
  private func saveProfile() async {
    isLoading = true
    message = ""
    defer { isLoading = false }

    guard let userId = authVM.userId else {
      message = "No active session. Please sign in again."
      return
    }

    guard let weight = Double(weightText), let age = Int(ageText) else {
      message = "Please enter a valid weight and age."
      return
    }

    let profile = UserProfile(
      id: userId,
      weight: weight,
      age: age,
      gender: gender
    )

    do {
      try await supabase
        .from("profiles")
        .upsert(profile)
        .execute()

      await authVM.refreshProfileState()
    } catch {
      message = "Failed to save profile: \(error.localizedDescription)"
    }
  }
}
