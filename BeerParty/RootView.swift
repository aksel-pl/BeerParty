import SwiftUI

struct RootView: View {
  @EnvironmentObject var authVM: AuthViewModel

  var body: some View {
    Group {
      if authVM.isSignedIn {
        switch authVM.profileState {
        case .unknown:
          ProgressView("Checking profile...")
        case .needsProfile:
          ProfileSetupView()
        case .complete:
          PreLobbyView()
        }
      } else {
        LoginView()
      }
    }
  }
}
