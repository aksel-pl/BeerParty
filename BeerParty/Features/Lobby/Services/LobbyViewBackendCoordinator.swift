import Foundation
import Supabase

struct LobbyViewBackendCoordinator {
  private let backendService = LobbyBackendService()

  func currentSessionAuthContext() async throws -> (userID: UUID, accessToken: String) {
    let session = try await supabase.auth.session
    return (session.user.id, session.accessToken)
  }

  func loadLobbyAnalytics(lobbyID: UUID) async throws -> (LobbyMeta, LobbyAnalyticsPayload) {
    async let meta = backendService.fetchLobbyMetaAndApplyExpiry(lobbyID: lobbyID)
    async let payload = backendService.fetchLobbyAnalytics(lobbyID: lobbyID)
    return try await (meta, payload)
  }

  func fetchNewDrinks(lobbyID: UUID, after timestamp: Date) async throws -> [LobbyDrink] {
    try await backendService.fetchNewDrinks(lobbyID: lobbyID, after: timestamp)
  }

  func insertDrink(
    lobbyID: UUID,
    name: String,
    volumeMl: Double,
    abv: Double
  ) async throws -> LobbyDrink {
    try await backendService.insertDrink(
      lobbyID: lobbyID,
      name: name,
      volumeMl: volumeMl,
      abv: abv
    )
  }

  func upsertMemberBAC(lobbyID: UUID, userID: UUID, bac: Double, timestamp: Date) async throws {
    try await backendService.upsertMemberBAC(
      lobbyID: lobbyID,
      userID: userID,
      bac: bac,
      timestamp: timestamp
    )
  }

  func revealInviteCode(lobbyID: UUID) async throws -> String {
    try await backendService.fetchInviteCode(lobbyID: lobbyID)
  }

  func closeLobby(lobbyID: UUID) async throws {
    try await backendService.closeLobby(lobbyID: lobbyID)
  }

  func leaveLobby(lobbyID: UUID) async throws {
    try await backendService.leaveLobby(lobbyID: lobbyID)
  }

  func deleteLobby(lobbyID: UUID) async throws {
    try await backendService.deleteLobby(lobbyID: lobbyID)
  }

  func fetchLocationSharingSettings(userID: UUID) async -> LocationSharingSettings {
    await backendService.fetchLocationSharingSettings(userID: userID)
  }

  func saveLocationSharingPreference(
    userID: UUID,
    shareForeground: Bool,
    shareBackground: Bool
  ) async throws {
    let update = UserProfileLocationPrefsUpdate(
      shareLocationForeground: shareForeground,
      shareLocationBackground: shareBackground
    )

    try await supabase
      .from("profiles")
      .update(update)
      .eq("id", value: userID)
      .execute()
  }

  func upsertMemberLocation(
    lobbyID: UUID,
    userID: UUID,
    lat: Double,
    lng: Double,
    timestamp: Date
  ) async throws {
    try await backendService.upsertMemberLocation(
      lobbyID: lobbyID,
      userID: userID,
      lat: lat,
      lng: lng,
      timestamp: timestamp
    )
  }

  func clearMemberLocation(lobbyID: UUID, userID: UUID) async throws {
    try await backendService.clearMemberLocation(lobbyID: lobbyID, userID: userID)
  }

  func fetchMemberLocations(lobbyID: UUID) async throws -> [MemberLocationData] {
    try await backendService.fetchMemberLocations(lobbyID: lobbyID)
  }
}

private struct UserProfileLocationPrefsUpdate: Encodable {
  let shareLocationForeground: Bool
  let shareLocationBackground: Bool

  enum CodingKeys: String, CodingKey {
    case shareLocationForeground = "share_location_foreground"
    case shareLocationBackground = "share_location_background"
  }
}
