//
//  LobbyBackendService.swift
//  BeerParty
//
//  Created by Codex on 2/14/26.
//
import Foundation
import Supabase

enum LobbyJoinError: LocalizedError {
  case noActiveLobbyForInviteCode
  case duplicateInviteCodes
  case inviteCodeUnavailable

  var errorDescription: String? {
    switch self {
    case .noActiveLobbyForInviteCode:
      return "No active lobby found for that invite code."
    case .duplicateInviteCodes:
      return "Multiple lobbies share that invite code. Ask the host to create a new unique code."
    case .inviteCodeUnavailable:
      return "Invite code is unavailable for this lobby."
    }
  }
}

enum LobbyLifecycleError: LocalizedError {
  case lobbyNotFound
  case notCreator
  case lobbyClosed

  var errorDescription: String? {
    switch self {
    case .lobbyNotFound:
      return "Lobby not found."
    case .notCreator:
      return "Only the lobby creator can perform this action."
    case .lobbyClosed:
      return "Lobby is closed. Drinks can no longer be added."
    }
  }
}

struct LobbyAnalyticsPayload {
  let currentUserID: UUID
  let members: [LobbyMemberData]
  let drinks: [LobbyDrink]
  let bacParamsByUserId: [UUID: LobbyBACParamsData]
}

struct LobbyMemberData: Identifiable {
  let userId: UUID
  let nickname: String
  let profilePicPath: String?

  var id: UUID { userId }
}

struct MemberLocationData: Identifiable {
  let userId: UUID
  let nickname: String
  let lat: Double
  let lng: Double
  let updatedAt: Date
  let profilePicPath: String?

  var id: UUID { userId }
}

struct LocationSharingSettings {
  let shareForeground: Bool
  let shareBackground: Bool
}

struct LobbyDrink: Identifiable {
  let id = UUID()
  let userId: UUID
  let name: String
  let volumeMl: Double
  let abv: Double
  let consumedAt: Date

  var alcoholGrams: Double {
    volumeMl * (abv / 100) * 0.789
  }
}

struct LobbyBACParamsData {
  let userId: UUID
  let tbw: Double
  let eliminationPerHourPromille: Double
}

struct LobbyMeta {
  let lobbyID: UUID
  let createdBy: UUID?
  let createdAt: Date?
  let isActive: Bool
}

struct LobbyBackendService {
  // Loads the invite code for a specific lobby.
  func fetchInviteCode(lobbyID: UUID) async throws -> String {
    let rows: [LobbyInviteCodeRow] = try await supabase
      .from("lobbies")
      .select("invite_code")
      .eq("id", value: lobbyID)
      .limit(1)
      .execute()
      .value

    guard let inviteCode = rows.first?.inviteCode, !inviteCode.isEmpty else {
      throw LobbyJoinError.inviteCodeUnavailable
    }
    return inviteCode
  }

  // Joins the current user to the lobby identified by invite code and initializes member rows.
  func joinLobby(inviteCode: String, nickname: String) async throws -> LobbyDestination {
    let session = try await supabase.auth.session
    let lobbyRows: [CreatedLobby] = try await supabase
      .from("lobbies")
      .select("id,name")
      .eq("invite_code", value: inviteCode)
      .eq("is_active", value: true)
      .limit(2)
      .execute()
      .value

    guard !lobbyRows.isEmpty else {
      throw LobbyJoinError.noActiveLobbyForInviteCode
    }
    guard lobbyRows.count == 1, let lobby = lobbyRows.first else {
      throw LobbyJoinError.duplicateInviteCodes
    }

    let memberRequest = CreateLobbyMemberRequest(
      lobbyId: lobby.id,
      userId: session.user.id,
      nickname: nickname,
      role: "guest"
    )

    try await supabase
      .from("lobby_members")
      .upsert(memberRequest, onConflict: "lobby_id,user_id")
      .execute()

    let memberStateRequest = UpsertMemberStateRequest(
      lobbyId: lobby.id,
      userId: session.user.id,
      bacEtimate: nil,
      lat: nil,
      lng: nil,
      updatedAt: Date()
    )

    try await supabase
      .from("member_state")
      .upsert(memberStateRequest, onConflict: "lobby_id,user_id")
      .execute()

    try await ensureCurrentUserBACParams(lobbyID: lobby.id, userID: session.user.id)

    return LobbyDestination(lobbyID: lobby.id, lobbyName: lobby.name)
  }

  // Loads lobby metadata and auto-closes it if it has been active for over 24 hours.
  func fetchLobbyMetaAndApplyExpiry(lobbyID: UUID) async throws -> LobbyMeta {
    let rows: [LobbyMetaRow] = try await supabase
      .from("lobbies")
      .select("id,created_by,created_at,is_active")
      .eq("id", value: lobbyID)
      .limit(1)
      .execute()
      .value

    guard var row = rows.first else {
      throw LobbyLifecycleError.lobbyNotFound
    }

    if row.isActive,
       let createdAt = row.createdAt.flatMap(parsePostgresTimestamp),
       Date().timeIntervalSince(createdAt) >= 24 * 3600
    {
      let update = LobbyActiveUpdateRequest(isActive: false)
      try? await supabase
        .from("lobbies")
        .update(update)
        .eq("id", value: lobbyID)
        .execute()
      row.isActive = false
    }

    return LobbyMeta(
      lobbyID: row.id,
      createdBy: row.createdBy,
      createdAt: row.createdAt.flatMap(parsePostgresTimestamp),
      isActive: row.isActive
    )
  }

  // Closes the lobby by setting is_active=false. Only the creator can do this.
  func closeLobby(lobbyID: UUID) async throws {
    let session = try await supabase.auth.session
    let update = LobbyActiveUpdateRequest(isActive: false)
    let updatedRows: [LobbyMetaRow] = try await supabase
      .from("lobbies")
      .update(update, returning: .representation)
      .eq("id", value: lobbyID)
      .eq("created_by", value: session.user.id)
      .execute()
      .value

    guard !updatedRows.isEmpty else {
      throw LobbyLifecycleError.notCreator
    }
  }

  // Removes the current user from this lobby and deletes their lobby-specific data.
  func leaveLobby(lobbyID: UUID) async throws {
    let session = try await supabase.auth.session
    let userID = session.user.id

    try await supabase
      .from("drinks")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .eq("user_id", value: userID)
      .execute()

    try await supabase
      .from("member_state")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .eq("user_id", value: userID)
      .execute()

    try await supabase
      .from("lobby_member_bac_params")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .eq("user_id", value: userID)
      .execute()

    try await supabase
      .from("lobby_members")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .eq("user_id", value: userID)
      .execute()
  }

  // Deletes the full lobby and all related data. Only the creator can do this.
  func deleteLobby(lobbyID: UUID) async throws {
    let session = try await supabase.auth.session
    let ownerRows: [LobbyMetaRow] = try await supabase
      .from("lobbies")
      .select("id,created_by,created_at,is_active")
      .eq("id", value: lobbyID)
      .eq("created_by", value: session.user.id)
      .limit(1)
      .execute()
      .value

    guard !ownerRows.isEmpty else {
      throw LobbyLifecycleError.notCreator
    }

    try await supabase
      .from("drinks")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .execute()

    try await supabase
      .from("member_state")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .execute()

    try await supabase
      .from("lobby_member_bac_params")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .execute()

    try await supabase
      .from("lobby_members")
      .delete()
      .eq("lobby_id", value: lobbyID)
      .execute()

    try await supabase
      .from("lobbies")
      .delete()
      .eq("id", value: lobbyID)
      .eq("created_by", value: session.user.id)
      .execute()
  }

  // Ensures the signed-in user has a BAC-parameter row for this lobby.
  func ensureBACParamsForCurrentUser(lobbyID: UUID) async throws {
    let session = try await supabase.auth.session
    try await ensureCurrentUserBACParams(lobbyID: lobbyID, userID: session.user.id)
  }

  // Creates a new drink row for the current user in the target lobby.
  func insertDrink(
    lobbyID: UUID,
    name: String,
    volumeMl: Double,
    abv: Double
  ) async throws -> LobbyDrink {
    let meta = try await fetchLobbyMetaAndApplyExpiry(lobbyID: lobbyID)
    guard meta.isActive else {
      throw LobbyLifecycleError.lobbyClosed
    }

    let session = try await supabase.auth.session
    let request = CreateDrinkRequest(
      lobbyId: lobbyID,
      userId: session.user.id,
      name: name,
      volumeMl: volumeMl,
      abv: abv,
      consumedAt: Date()
    )

    try await supabase
      .from("drinks")
      .insert(request)
      .execute()

    return LobbyDrink(
      userId: session.user.id,
      name: name,
      volumeMl: volumeMl,
      abv: abv,
      consumedAt: request.consumedAt
    )
  }

  // Fetches members, drinks, and BAC parameters needed by the lobby BAC UI.
  func fetchLobbyAnalytics(lobbyID: UUID) async throws -> LobbyAnalyticsPayload {
    let session = try await supabase.auth.session
    try? await ensureCurrentUserBACParams(lobbyID: lobbyID, userID: session.user.id)

    let memberRows: [LobbyMemberRow] = try await supabase
      .from("lobby_members")
      .select("user_id,nickname")
      .eq("lobby_id", value: lobbyID)
      .execute()
      .value

    let memberIDs = memberRows.map(\.userId)

    var profilePicByUserID: [UUID: String] = [:]
    for memberID in memberIDs {
      if let profileRow: ProfilePhotoRow = try? await supabase
        .from("profiles")
        .select("id,profile_pic_path")
        .eq("id", value: memberID)
        .single()
        .execute()
        .value
      {
        profilePicByUserID[memberID] = profileRow.profilePicPath
      }
    }

    let members = memberRows.map {
      let cleanedNickname = ($0.nickname ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return LobbyMemberData(
        userId: $0.userId,
        nickname: cleanedNickname.isEmpty ? "Member" : cleanedNickname,
        profilePicPath: profilePicByUserID[$0.userId]
      )
    }

    let drinkRows: [DrinkRow] = try await supabase
      .from("drinks")
      .select("user_id,name,volume_ml,abv,consumed_at")
      .eq("lobby_id", value: lobbyID)
      .order("consumed_at", ascending: true)
      .execute()
      .value

    let drinks = drinkRows.compactMap { row -> LobbyDrink? in
      guard let consumedAt = parsePostgresTimestamp(row.consumedAt) else { return nil }
      return LobbyDrink(
        userId: row.userId,
        name: row.name,
        volumeMl: row.volumeMl,
        abv: row.abv,
        consumedAt: consumedAt
      )
    }

    var bacParamsByUserId: [UUID: LobbyBACParamsData] = [:]
    do {
      let bacParamsRows: [LobbyBACParamsRow] = try await supabase
        .from("lobby_member_bac_params")
        .select("user_id,tbw,elim_rate")
        .eq("lobby_id", value: lobbyID)
        .execute()
        .value

      for row in bacParamsRows {
        guard let tbw = row.tbw, let elimRate = row.elimRate else { continue }
        bacParamsByUserId[row.userId] = LobbyBACParamsData(
          userId: row.userId,
          tbw: tbw,
          eliminationPerHourPromille: elimRate
        )
      }
    } catch {
      // Allow tracker to continue with fallback parameters if this table/policy is not ready yet.
    }

    return LobbyAnalyticsPayload(
      currentUserID: session.user.id,
      members: members,
      drinks: drinks,
      bacParamsByUserId: bacParamsByUserId
    )
  }

  func fetchLocationSharingSettings(userID: UUID) async -> LocationSharingSettings {
    do {
      let profile: UserProfile = try await supabase
        .from("profiles")
        .select("id,weight,age,gender,profile_pic_path,share_location_foreground,share_location_background")
        .eq("id", value: userID)
        .single()
        .execute()
        .value
      return LocationSharingSettings(
        shareForeground: profile.shareLocationForeground,
        shareBackground: profile.shareLocationBackground
      )
    } catch {
      return LocationSharingSettings(shareForeground: false, shareBackground: false)
    }
  }

  func upsertMemberLocation(
    lobbyID: UUID,
    userID: UUID,
    lat: Double,
    lng: Double,
    timestamp: Date
  ) async throws {
    let request = UpdateMemberLocationRequest(
      lobbyId: lobbyID,
      userId: userID,
      lat: lat,
      lng: lng,
      updatedAt: timestamp
    )

    try await supabase
      .from("member_state")
      .upsert(request, onConflict: "lobby_id,user_id")
      .execute()
  }

  func clearMemberLocation(
    lobbyID: UUID,
    userID: UUID,
    timestamp: Date = Date()
  ) async throws {
    let request = UpdateMemberLocationRequest(
      lobbyId: lobbyID,
      userId: userID,
      lat: nil,
      lng: nil,
      updatedAt: timestamp
    )

    try await supabase
      .from("member_state")
      .upsert(request, onConflict: "lobby_id,user_id")
      .execute()
  }

  func fetchMemberLocations(lobbyID: UUID) async throws -> [MemberLocationData] {
    let memberRows: [LobbyMemberRow] = try await supabase
      .from("lobby_members")
      .select("user_id,nickname")
      .eq("lobby_id", value: lobbyID)
      .execute()
      .value

    let stateRows: [MemberStateLocationRow] = try await supabase
      .from("member_state")
      .select("user_id,lat,lng,updated_at")
      .eq("lobby_id", value: lobbyID)
      .execute()
      .value

    var profilePicByUserID: [UUID: String] = [:]
    for member in memberRows {
      if let profileRow: ProfilePhotoRow = try? await supabase
        .from("profiles")
        .select("id,profile_pic_path")
        .eq("id", value: member.userId)
        .single()
        .execute()
        .value
      {
        profilePicByUserID[member.userId] = profileRow.profilePicPath
      }
    }

    let nicknameByUserID = Dictionary(
      uniqueKeysWithValues: memberRows.map { row in
        let cleanedNickname = (row.nickname ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return (row.userId, cleanedNickname.isEmpty ? "Member" : cleanedNickname)
      }
    )

    return stateRows.compactMap { row in
      guard let lat = row.lat, let lng = row.lng else { return nil }
      guard let updatedAt = parsePostgresTimestamp(row.updatedAt) else { return nil }
      let nickname = nicknameByUserID[row.userId] ?? "Member"
      return MemberLocationData(
        userId: row.userId,
        nickname: nickname,
        lat: lat,
        lng: lng,
        updatedAt: updatedAt,
        profilePicPath: profilePicByUserID[row.userId]
      )
    }
  }

  // Fetches only drinks newer than the provided timestamp for cheap live updates.
  func fetchNewDrinks(
    lobbyID: UUID,
    after timestamp: Date
  ) async throws -> [LobbyDrink] {
    let rows: [DrinkRow] = try await supabase
      .from("drinks")
      .select("user_id,name,volume_ml,abv,consumed_at")
      .eq("lobby_id", value: lobbyID)
      .gt("consumed_at", value: Self.iso8601WithFractionalSeconds.string(from: timestamp))
      .order("consumed_at", ascending: true)
      .execute()
      .value

    return rows.compactMap { row in
      guard let consumedAt = parsePostgresTimestamp(row.consumedAt) else { return nil }
      return LobbyDrink(
        userId: row.userId,
        name: row.name,
        volumeMl: row.volumeMl,
        abv: row.abv,
        consumedAt: consumedAt
      )
    }
  }

  // Writes the user's latest BAC estimate into member_state.
  func upsertMemberBAC(
    lobbyID: UUID,
    userID: UUID,
    bac: Double,
    timestamp: Date
  ) async throws {
    let request = UpsertMemberBACRequest(
      lobbyId: lobbyID,
      userId: userID,
      bacEstimate: bac,
      updatedAt: timestamp
    )

    do {
      try await supabase
        .from("member_state")
        .upsert(request, onConflict: "lobby_id,user_id")
        .execute()
    } catch {
      let legacyRequest = UpsertMemberBACLegacyRequest(
        lobbyId: lobbyID,
        userId: userID,
        bacEtimate: bac,
        updatedAt: timestamp
      )
      try await supabase
        .from("member_state")
        .upsert(legacyRequest, onConflict: "lobby_id,user_id")
        .execute()
    }
  }

  // Parses timestamptz strings from Postgres into Date values.
  private func parsePostgresTimestamp(_ raw: String) -> Date? {
    if let withFractions = Self.iso8601WithFractionalSeconds.date(from: raw) {
      return withFractions
    }
    return Self.iso8601.date(from: raw)
  }

  // Ensures the current user has derived BAC parameters saved for this lobby.
  private func ensureCurrentUserBACParams(lobbyID: UUID, userID: UUID) async throws {
    let existing: [LobbyBACParamsRow] = try await supabase
      .from("lobby_member_bac_params")
      .select("user_id,tbw,elim_rate")
      .eq("lobby_id", value: lobbyID)
      .eq("user_id", value: userID)
      .limit(1)
      .execute()
      .value

    if !existing.isEmpty {
      return
    }

    let derived: LobbyBACParamsData
    do {
      let profile: UserProfile = try await supabase
        .from("profiles")
        .select("id,weight,age,gender")
        .eq("id", value: userID)
        .single()
        .execute()
        .value
      derived = deriveBACParametersFromProfile(profile)
    } catch {
      derived = LobbyBACParamsData(
        userId: userID,
        tbw: 40,
        eliminationPerHourPromille: 0.14
      )
    }
    let request = UpsertLobbyBACParamsRequest(
      lobbyId: lobbyID,
      userId: userID,
      tbw: derived.tbw,
      elimRate: derived.eliminationPerHourPromille,
      updatedAt: Date()
    )

    try await supabase
      .from("lobby_member_bac_params")
      .upsert(request, onConflict: "lobby_id,user_id")
      .execute()
  }

  // Derives TBW and elimination rate from profile fields once per user/lobby.
  private func deriveBACParametersFromProfile(_ profile: UserProfile) -> LobbyBACParamsData {
    let weightKg = max(40, profile.weight / 2.20462)
    let age = max(18, profile.age)
    let gender = profile.gender.lowercased()

    if gender.contains("female") {
      return LobbyBACParamsData(
        userId: profile.id,
        tbw: max(20, 14.46 + 0.2549 * weightKg),
        eliminationPerHourPromille: 0.15
      )
    }
    if gender.contains("male") {
      return LobbyBACParamsData(
        userId: profile.id,
        tbw: max(20, 20.03 - 0.1183 * Double(age) + 0.3626 * weightKg),
        eliminationPerHourPromille: 0.13
      )
    }
    return LobbyBACParamsData(
      userId: profile.id,
      tbw: max(20, 17.25 + 0.308 * weightKg),
      eliminationPerHourPromille: 0.14
    )
  }

  private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let iso8601: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
}

private struct LobbyMemberRow: Decodable {
  let userId: UUID
  let nickname: String?

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case nickname
  }
}

private struct ProfilePhotoRow: Decodable {
  let id: UUID
  let profilePicPath: String?

  enum CodingKeys: String, CodingKey {
    case id
    case profilePicPath = "profile_pic_path"
  }
}

private struct MemberStateLocationRow: Decodable {
  let userId: UUID
  let lat: Double?
  let lng: Double?
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case lat
    case lng
    case updatedAt = "updated_at"
  }
}

private struct DrinkRow: Decodable {
  let userId: UUID
  let name: String
  let volumeMl: Double
  let abv: Double
  let consumedAt: String

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case name
    case volumeMl = "volume_ml"
    case abv
    case consumedAt = "consumed_at"
  }
}

private struct LobbyBACParamsRow: Decodable {
  let userId: UUID
  let tbw: Double?
  let elimRate: Double?

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case tbw
    case elimRate = "elim_rate"
  }
}

private struct LobbyInviteCodeRow: Decodable {
  let inviteCode: String

  enum CodingKeys: String, CodingKey {
    case inviteCode = "invite_code"
  }
}

private struct LobbyMetaRow: Decodable {
  let id: UUID
  let createdBy: UUID?
  let createdAt: String?
  var isActive: Bool

  enum CodingKeys: String, CodingKey {
    case id
    case createdBy = "created_by"
    case createdAt = "created_at"
    case isActive = "is_active"
  }
}

private struct LobbyActiveUpdateRequest: Encodable {
  let isActive: Bool

  enum CodingKeys: String, CodingKey {
    case isActive = "is_active"
  }
}
