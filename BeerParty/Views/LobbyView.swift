//
//  LobbyView.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//
import SwiftUI
import Charts
import Combine
import MapKit
import CoreLocation

struct LobbyView: View {
  let lobbyID: UUID
  let lobbyName: String
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase

  @State private var drinkName: String = ""
  @State private var volumeMl: String = ""
  @State private var abv: String = ""
  @State private var statusMessage: String = ""
  @State private var isSubmitting: Bool = false
  @State private var isLoadingAnalytics: Bool = false
  @State private var now: Date = Date()
  @State private var members: [LobbyMemberData] = []
  @State private var drinks: [LobbyDrink] = []
  @State private var bacParamsByUserId: [UUID: LobbyBACParamsData] = [:]
  @State private var currentUserID: UUID?
  @State private var isLobbyActive: Bool = true
  @State private var isLobbyCreator: Bool = false
  @State private var lastBacSyncedAt: Date?
  @State private var lastBacSyncedValue: Double?
  @State private var lastDrinkCursor: Date?
  @State private var revealedInviteCode: String?
  @State private var isRevealingInviteCode: Bool = false
  @State private var hideInviteCodeTask: Task<Void, Never>?
  @State private var isLifecycleActionLoading: Bool = false
  @State private var isDeleteArmed: Bool = false
  @State private var clearDeleteArmTask: Task<Void, Never>?
  @State private var mapRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
  )
  @State private var locationRows: [MemberLocationData] = []
  @State private var currentUserShareForeground = false
  @State private var currentUserShareBackground = false
  @State private var hasCenteredMap = false

  private let liveTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
  private let bacSyncTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
  private let locationRefreshTimer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
  private let backendCoordinator = LobbyViewBackendCoordinator()
  @StateObject private var locationTrackingService = LocationTrackingService()
  private let imageService = ProfileImageService()
  private let quickAddColumns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12)
  ]

  // Renders the lobby UI, including live BAC, chart, and drink entry controls.
  var body: some View {
    let snapshot = buildBacSnapshot(at: now)

    ZStack(alignment: .top) {
      Form {
        Section {
          Color.clear
            .frame(height: 156)
            .listRowBackground(Color.clear)
        }

        Section {
          Text(lobbyName)
            .font(.largeTitle.bold())

          Text("Lobby ID: \(lobbyID.uuidString)")
            .font(.footnote)
            .foregroundStyle(.secondary)

          Text(isLobbyActive ? "Status: Active" : "Status: Closed")
            .font(.footnote)
            .foregroundStyle(isLobbyActive ? .green : .red)

          Button(isRevealingInviteCode ? "Revealing..." : "Reveal invite code") {
            Task { await revealInviteCodeTemporarily() }
          }
          .font(.footnote)
          .disabled(isRevealingInviteCode)

          if let revealedInviteCode {
            Text("Invite code: \(revealedInviteCode)")
              .font(.footnote.monospaced())
          }
        }

        Section("Live BAC") {
          if isLoadingAnalytics {
            ProgressView("Loading lobby drinks...")
          } else if snapshot.current.isEmpty {
            Text("No members found in this lobby.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(snapshot.current) { member in
              HStack {
                Text(member.nickname)
                Spacer()
                Text("\(member.bac, specifier: "%.2f")‰")
                  .monospacedDigit()
              }
            }
          }
        }

        Section("Lobby Intoxication Graph") {
          if snapshot.points.isEmpty {
            Text("No drinks recorded yet.")
              .foregroundStyle(.secondary)
          } else {
            Chart(snapshot.points) { point in
              LineMark(
                x: .value("Time", point.time),
                y: .value("BAC", point.bac),
                series: .value("Member", point.nickname)
              )
              .interpolationMethod(.catmullRom)
              .foregroundStyle(by: .value("Member", point.nickname))
            }
            .chartYScale(domain: 0...snapshot.maxY)
            .frame(height: 230)
          }
        }

        Section("Member Map") {
          if scenePhase != .active {
            Text("Map pauses while app is in background.")
              .foregroundStyle(.secondary)
          } else if visibleLocationRows.isEmpty {
            Text("No live member locations yet.")
              .foregroundStyle(.secondary)
          } else {
            Map(coordinateRegion: $mapRegion, annotationItems: visibleLocationRows) { row in
              MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: row.lat, longitude: row.lng)) {
                VStack(spacing: 4) {
                  mapAvatar(for: row.profilePicPath)
                  Text(row.nickname)
                    .font(.caption2)
                    .lineLimit(1)
                }
              }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 10))
          }

          Toggle("Share my location in foreground", isOn: $currentUserShareForeground)
            .onChange(of: currentUserShareForeground) { _, _ in
              Task { await updateLocationSharingPreference() }
            }

          Toggle("Share my location in background", isOn: $currentUserShareBackground)
            .disabled(!currentUserShareForeground)
            .onChange(of: currentUserShareBackground) { _, _ in
              Task { await updateLocationSharingPreference() }
            }
        }

        Section("Add Drink") {
          TextField("Drink name", text: $drinkName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

          TextField("Volume (ml)", text: $volumeMl)
            .keyboardType(.decimalPad)

          TextField("ABV (%)", text: $abv)
            .keyboardType(.decimalPad)

          Button(isSubmitting ? "Adding..." : "Add Drink") {
            Task { await addManualDrink() }
          }
          .disabled(isSubmitting || !canAddManualDrink || !isLobbyActive)
        }

        Section("Lobby Actions") {
          if isLobbyCreator {
            Button("Closing Time") {
              Task { await closeLobby() }
            }
            .disabled(isLifecycleActionLoading || !isLobbyActive)

            Button(isDeleteArmed ? "Confirm Delete Lobby" : "Delete Lobby") {
              Task { await deleteLobbyWithTwoStepConfirmation() }
            }
            .tint(.red)
            .disabled(isLifecycleActionLoading)
          } else {
            Button("Leave Lobby") {
              Task { await leaveLobby() }
            }
            .tint(.orange)
            .disabled(isLifecycleActionLoading)
          }
        }

        if !statusMessage.isEmpty {
          Section {
            Text(statusMessage)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
      }

      LazyVGrid(columns: quickAddColumns, spacing: 8) {
        quickAddEmojiButton("🍺") {
          Task { await addDrink(name: "Beer", volumeMl: 330, abv: 5) }
        }
        .disabled(isSubmitting || !isLobbyActive)

        quickAddEmojiButton("🍷") {
          Task { await addDrink(name: "Wine", volumeMl: 150, abv: 12) }
        }
        .disabled(isSubmitting || !isLobbyActive)

        quickAddEmojiButton("🥃") {
          Task { await addDrink(name: "Shot", volumeMl: 44, abv: 40) }
        }
        .disabled(isSubmitting || !isLobbyActive)

        quickAddEmojiButton("💧") {
          Task { await addDrink(name: "Water", volumeMl: 250, abv: 0) }
        }
        .disabled(isSubmitting || !isLobbyActive)
      }
      .padding(.horizontal, 14)
      .padding(.top, 6)
      .background(Color.clear)
      .zIndex(3)
    }
    .navigationTitle("Lobby")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await loadLobbyAnalytics()
    }
    .refreshable {
      await loadLobbyAnalytics()
    }
    .onReceive(liveTimer) { latest in
      now = latest
      Task { await refreshNewDrinksIfNeeded() }
    }
    .onReceive(bacSyncTimer) { latest in
      Task { await syncCurrentUserBACIfNeeded(at: latest) }
    }
    .onReceive(locationRefreshTimer) { _ in
      Task { await refreshMemberLocations() }
    }
    .onDisappear {
      hideInviteCodeTask?.cancel()
      hideInviteCodeTask = nil
      clearDeleteArmTask?.cancel()
      clearDeleteArmTask = nil
      locationTrackingService.stopTracking()
    }
  }

  private var trimmedDrinkName: String {
    drinkName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var canAddManualDrink: Bool {
    !trimmedDrinkName.isEmpty && parsedVolumeMl != nil && parsedAbv != nil
  }

  private var parsedVolumeMl: Double? {
    guard let parsed = Double(volumeMl), parsed > 0 else { return nil }
    return parsed
  }

  private var parsedAbv: Double? {
    guard let parsed = Double(abv), parsed >= 0 else { return nil }
    return parsed
  }

  private var visibleLocationRows: [MemberLocationData] {
    let staleCutoff = Date().addingTimeInterval(-5 * 60)
    return locationRows.filter { $0.updatedAt >= staleCutoff }
  }

  private func quickAddEmojiButton(_ emoji: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(emoji)
        .font(.system(size: 34))
        .frame(maxWidth: .infinity)
        .frame(height: 60)
    }
    .buttonStyle(GlassButtonStyle())
  }

  @ViewBuilder
  private func mapAvatar(for profilePicPath: String?) -> some View {
    if let url = imageService.publicImageURL(for: profilePicPath) {
      AsyncImage(url: url) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        default:
          Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFill()
            .symbolRenderingMode(.hierarchical)
        }
      }
      .frame(width: 38, height: 38)
      .clipShape(Circle())
      .overlay(Circle().stroke(Color.white, lineWidth: 2))
      .shadow(radius: 2)
    } else {
      Image(systemName: "person.crop.circle.fill")
        .resizable()
        .scaledToFill()
        .symbolRenderingMode(.hierarchical)
        .frame(width: 38, height: 38)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 2))
        .shadow(radius: 2)
    }
  }

  @MainActor
  // Validates manual inputs and forwards them to the shared add-drink flow.
  private func addManualDrink() async {
    guard let parsedVolumeMl, let parsedAbv else { return }
    await addDrink(name: trimmedDrinkName, volumeMl: parsedVolumeMl, abv: parsedAbv)
  }

  @MainActor
  // Inserts a drink via the backend service and refreshes local state/sync.
  private func addDrink(name: String, volumeMl volumeMlValue: Double, abv abvValue: Double) async {
    guard isLobbyActive else {
      statusMessage = "This lobby is closed. Drinks can no longer be added."
      return
    }

    isSubmitting = true
    statusMessage = ""
    defer { isSubmitting = false }

    do {
      let insertedDrink = try await backendCoordinator.insertDrink(
        lobbyID: lobbyID,
        name: name,
        volumeMl: volumeMlValue,
        abv: abvValue
      )
      currentUserID = insertedDrink.userId

      drinks.append(insertedDrink)
      drinks.sort { $0.consumedAt < $1.consumedAt }
      lastDrinkCursor = drinks.map(\.consumedAt).max()

      if name == trimmedDrinkName {
        drinkName = ""
        volumeMl = ""
        abv = ""
      }
      statusMessage = "Added \(name)."
      await syncCurrentUserBACIfNeeded(at: insertedDrink.consumedAt, force: true)
    } catch {
      statusMessage = "Failed to add drink: \(error.localizedDescription)"
    }
  }

  @MainActor
  // Loads lobby members, drinks, and BAC parameters used for local BAC calculations.
  private func loadLobbyAnalytics() async {
    isLoadingAnalytics = true
    defer { isLoadingAnalytics = false }

    do {
      let (meta, payload) = try await backendCoordinator.loadLobbyAnalytics(lobbyID: lobbyID)
      isLobbyActive = meta.isActive
      isLobbyCreator = (meta.createdBy == payload.currentUserID)
      currentUserID = payload.currentUserID
      members = payload.members
      drinks = payload.drinks
      bacParamsByUserId = payload.bacParamsByUserId
      lastDrinkCursor = payload.drinks.map(\.consumedAt).max() ?? Date()
      now = Date()
      if !isLobbyActive {
        statusMessage = "Lobby closed. Drinking is disabled."
      }
      await syncCurrentUserBACIfNeeded(at: now, force: true)
      await loadLocationExperience()
    } catch {
      statusMessage = "Failed to load BAC tracker: \(error.localizedDescription)"
    }
  }

  // Pulls only new drinks since the last cursor to keep the graph fresh cheaply.
  private func refreshNewDrinksIfNeeded() async {
    guard let cursor = lastDrinkCursor else { return }
    do {
      let newDrinks = try await backendCoordinator.fetchNewDrinks(lobbyID: lobbyID, after: cursor)
      guard !newDrinks.isEmpty else { return }

      drinks.append(contentsOf: newDrinks)
      drinks.sort { $0.consumedAt < $1.consumedAt }
      lastDrinkCursor = drinks.map(\.consumedAt).max()
    } catch {
      // Ignore periodic refresh failures; manual refresh still reloads everything.
    }
  }

  @MainActor
  private func loadLocationExperience() async {
    guard let currentUserID else { return }

    let settings = await backendCoordinator.fetchLocationSharingSettings(userID: currentUserID)
    currentUserShareForeground = settings.shareForeground
    currentUserShareBackground = settings.shareBackground

    locationTrackingService.onLocationUpdate = { location in
      Task { await handleOwnLocationUpdate(location) }
    }

    refreshLocationTrackingState()
    await refreshMemberLocations()
  }

  @MainActor
  private func refreshLocationTrackingState() {
    if currentUserShareForeground {
      locationTrackingService.startTracking(allowsBackground: currentUserShareBackground)
    } else {
      locationTrackingService.stopTracking()
      if let currentUserID {
        Task {
          try? await backendCoordinator.clearMemberLocation(lobbyID: lobbyID, userID: currentUserID)
          await refreshMemberLocations()
        }
      }
    }
  }

  @MainActor
  private func updateLocationSharingPreference() async {
    if !currentUserShareForeground {
      currentUserShareBackground = false
    }

    guard let userID = currentUserID else { return }
    do {
      try await backendCoordinator.saveLocationSharingPreference(
        userID: userID,
        shareForeground: currentUserShareForeground,
        shareBackground: currentUserShareForeground && currentUserShareBackground
      )
      refreshLocationTrackingState()
    } catch {
      statusMessage = "Failed to save location preference: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func handleOwnLocationUpdate(_ location: CLLocation) async {
    guard currentUserShareForeground else { return }
    guard let currentUserID else { return }

    do {
      try await backendCoordinator.upsertMemberLocation(
        lobbyID: lobbyID,
        userID: currentUserID,
        lat: location.coordinate.latitude,
        lng: location.coordinate.longitude,
        timestamp: Date()
      )
      await refreshMemberLocations()
    } catch {
      statusMessage = "Failed to sync location: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func refreshMemberLocations() async {
    do {
      let rows = try await backendCoordinator.fetchMemberLocations(lobbyID: lobbyID)
      locationRows = rows

      if !hasCenteredMap, let first = rows.first {
        mapRegion.center = CLLocationCoordinate2D(latitude: first.lat, longitude: first.lng)
        hasCenteredMap = true
      }
    } catch {
      // Ignore transient map refresh failures.
    }
  }

  @MainActor
  // Fetches and shows the lobby invite code briefly, then hides it again.
  private func revealInviteCodeTemporarily() async {
    isRevealingInviteCode = true
    defer { isRevealingInviteCode = false }

    do {
      let inviteCode = try await backendCoordinator.revealInviteCode(lobbyID: lobbyID)
      revealedInviteCode = inviteCode
      hideInviteCodeTask?.cancel()
      hideInviteCodeTask = Task {
        try? await Task.sleep(nanoseconds: 10_000_000_000)
        if !Task.isCancelled {
          await MainActor.run {
            revealedInviteCode = nil
          }
        }
      }
    } catch {
      statusMessage = "Failed to reveal invite code: \(error.localizedDescription)"
    }
  }

  @MainActor
  // Allows only the creator to manually close the lobby.
  private func closeLobby() async {
    isLifecycleActionLoading = true
    defer { isLifecycleActionLoading = false }

    do {
      try await backendCoordinator.closeLobby(lobbyID: lobbyID)
      isLobbyActive = false
      statusMessage = "Closing time. Lobby is now closed."
    } catch {
      statusMessage = "Failed to close lobby: \(error.localizedDescription)"
    }
  }

  @MainActor
  // Removes the current member and their lobby-specific data, then exits the lobby view.
  private func leaveLobby() async {
    isLifecycleActionLoading = true
    defer { isLifecycleActionLoading = false }

    do {
      try await backendCoordinator.leaveLobby(lobbyID: lobbyID)
      dismiss()
    } catch {
      statusMessage = "Failed to leave lobby: \(error.localizedDescription)"
    }
  }

  @MainActor
  // Requires two taps to delete a lobby and all associated lobby data.
  private func deleteLobbyWithTwoStepConfirmation() async {
    if !isDeleteArmed {
      isDeleteArmed = true
      statusMessage = "Tap 'Confirm Delete Lobby' within 8 seconds to delete permanently."
      clearDeleteArmTask?.cancel()
      clearDeleteArmTask = Task {
        try? await Task.sleep(nanoseconds: 8_000_000_000)
        if !Task.isCancelled {
          await MainActor.run {
            isDeleteArmed = false
          }
        }
      }
      return
    }

    isLifecycleActionLoading = true
    defer { isLifecycleActionLoading = false }

    do {
      try await backendCoordinator.deleteLobby(lobbyID: lobbyID)
      isDeleteArmed = false
      clearDeleteArmTask?.cancel()
      clearDeleteArmTask = nil
      dismiss()
    } catch {
      statusMessage = "Failed to delete lobby: \(error.localizedDescription)"
    }
  }

  @MainActor
  // Periodically upserts this user's computed BAC into member_state.
  private func syncCurrentUserBACIfNeeded(at timestamp: Date, force: Bool = false) async {
    let minSyncIntervalSeconds: TimeInterval = 240
    if !force, let lastSyncedAt = lastBacSyncedAt, timestamp.timeIntervalSince(lastSyncedAt) < minSyncIntervalSeconds {
      return
    }

    guard let userId = currentUserID else { return }
    let snapshot = buildBacSnapshot(at: timestamp)
    guard let myBAC = snapshot.current.first(where: { $0.userId == userId })?.bac else { return }

    if !force, let lastValue = lastBacSyncedValue, abs(lastValue - myBAC) < 0.005 {
      return
    }

    do {
      try await backendCoordinator.upsertMemberBAC(
        lobbyID: lobbyID,
        userID: userId,
        bac: myBAC,
        timestamp: timestamp
      )

      lastBacSyncedAt = timestamp
      lastBacSyncedValue = myBAC
    } catch {
      statusMessage = "Failed to sync BAC: \(error.localizedDescription)"
    }
  }

  // Builds current BAC values and timeline points for every member.
  private func buildBacSnapshot(at timestamp: Date) -> BacSnapshot {
    let sortedMembers = members.sorted {
      $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
    }
    var current: [MemberBACSnapshot] = []
    var points: [BACPoint] = []
    let hasAnyDrinks = !drinks.isEmpty

    let allDrinkTimes = drinks.map(\.consumedAt)
    let startTime = allDrinkTimes.min() ?? timestamp

    for member in sortedMembers {
      let memberDrinks = drinks.filter { $0.userId == member.userId }.sorted { $0.consumedAt < $1.consumedAt }
      let params = bacParamsByUserId[member.userId]
      let simulation = simulateBACTimeline(
        params: params,
        drinks: memberDrinks,
        start: startTime,
        end: timestamp,
        stepMinutes: 10
      )

      current.append(
        MemberBACSnapshot(
          userId: member.userId,
          nickname: member.nickname,
          bac: simulation.currentBAC
        )
      )

      if hasAnyDrinks {
        points.append(contentsOf: simulation.points.map {
          BACPoint(
            id: "\(member.userId.uuidString)-\($0.time.timeIntervalSince1970)",
            nickname: member.nickname,
            time: $0.time,
            bac: $0.bac
          )
        })
      }
    }

    let maxY = max(0.05, points.map(\.bac).max() ?? 0.05)
    let sortedCurrent = current.sorted { lhs, rhs in
      if lhs.bac == rhs.bac {
        return lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending
      }
      return lhs.bac > rhs.bac
    }
    return BacSnapshot(current: sortedCurrent, points: points, maxY: maxY)
  }

  // Simulates BAC over time using absorption and elimination at fixed time steps.
  private func simulateBACTimeline(
    params: LobbyBACParamsData?,
    drinks: [LobbyDrink],
    start: Date,
    end: Date,
    stepMinutes: Int
  ) -> BACSimulationResult {
    guard end >= start else {
      return BACSimulationResult(points: [TimelineBACPoint(time: end, bac: 0)], currentBAC: 0)
    }

    let parameters = bacParameters(for: params)
    let eliminationPerHourGrams = (parameters.eliminationPerHourPromille * parameters.tbw) / 0.84
    let sortedDrinks = drinks.sorted { $0.consumedAt < $1.consumedAt }
    let stepSeconds = TimeInterval(stepMinutes * 60)

    var points: [TimelineBACPoint] = []
    var currentTime = start
    var alcoholInBodyGrams: Double = 0

    points.append(TimelineBACPoint(time: currentTime, bac: 0))

    while currentTime < end {
      let nextTime = min(end, currentTime.addingTimeInterval(stepSeconds))
      let dtHours = nextTime.timeIntervalSince(currentTime) / 3600
      if dtHours <= 0 {
        currentTime = nextTime
        continue
      }

      var absorbedGrams: Double = 0
      for drink in sortedDrinks {
        let previousHours = currentTime.timeIntervalSince(drink.consumedAt) / 3600
        let currentHours = nextTime.timeIntervalSince(drink.consumedAt) / 3600
        let previousFraction = absorbedFraction(hoursSinceDrink: previousHours, abv: drink.abv)
        let currentFraction = absorbedFraction(hoursSinceDrink: currentHours, abv: drink.abv)
        let deltaFraction = max(0, currentFraction - previousFraction)
        absorbedGrams += drink.alcoholGrams * deltaFraction
      }

      alcoholInBodyGrams = max(
        0,
        alcoholInBodyGrams + absorbedGrams - eliminationPerHourGrams * dtHours
      )

      let currentBAC = max(0, (alcoholInBodyGrams / parameters.tbw) * 0.84)
      points.append(TimelineBACPoint(time: nextTime, bac: currentBAC))

      currentTime = nextTime
    }

    return BACSimulationResult(points: points, currentBAC: points.last?.bac ?? 0)
  }

  // Uses precomputed per-member BAC parameters to avoid reading raw profiles.
  private func bacParameters(for params: LobbyBACParamsData?) -> BACParameters {
    guard let params else {
      return BACParameters(tbw: 40, eliminationPerHourPromille: 0.14)
    }
    return BACParameters(
      tbw: max(20, params.tbw),
      eliminationPerHourPromille: max(0.08, min(0.2, params.eliminationPerHourPromille))
    )
  }

  // Returns what fraction of a drink is absorbed based on elapsed time and ABV.
  private func absorbedFraction(hoursSinceDrink: Double, abv: Double) -> Double {
    guard hoursSinceDrink > 0 else { return 0 }
    let absorptionDurationHours = min(max(1.6 - (abv * 0.03), 0.25), 1.6)
    return min(1, hoursSinceDrink / absorptionDurationHours)
  }

}

private struct BACParameters {
  let tbw: Double
  let eliminationPerHourPromille: Double
}

private struct TimelineBACPoint {
  let time: Date
  let bac: Double
}

private struct BACSimulationResult {
  let points: [TimelineBACPoint]
  let currentBAC: Double
}

private struct MemberBACSnapshot: Identifiable {
  let userId: UUID
  let nickname: String
  let bac: Double

  var id: UUID { userId }
}

private struct BACPoint: Identifiable {
  let id: String
  let nickname: String
  let time: Date
  let bac: Double
}

private struct BacSnapshot {
  let current: [MemberBACSnapshot]
  let points: [BACPoint]
  let maxY: Double
}
