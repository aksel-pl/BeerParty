import SwiftUI

struct LiquidGlassButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .fontWeight(.semibold)
      .padding(.vertical, 10)
      .padding(.horizontal, 14)
      .frame(maxWidth: .infinity, alignment: .center)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [
                .white.opacity(0.85),
                .white.opacity(0.15)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      )
      .shadow(color: .white.opacity(0.16), radius: 8, x: 0, y: 3)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .opacity(configuration.isPressed ? 0.9 : 1)
      .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
  }
}

struct GlassProminentButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .fontWeight(.semibold)
      .padding(.vertical, 10)
      .padding(.horizontal, 14)
      .frame(maxWidth: .infinity, alignment: .center)
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [
                .white.opacity(configuration.isPressed ? 0.9 : 0.75),
                .white.opacity(configuration.isPressed ? 0.45 : 0.22)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1.3
          )
      )
      .shadow(color: .white.opacity(configuration.isPressed ? 0.1 : 0.2), radius: 9, x: 0, y: 4)
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .opacity(configuration.isPressed ? 0.86 : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

struct RainbowGlowFrameModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .overlay {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(
            AngularGradient(
              colors: [
                .red,
                .orange,
                .yellow,
                .green,
                .cyan,
                .blue,
                .purple,
                .pink,
                .red
              ],
              center: .center
            ),
            lineWidth: 2
          )
          .blur(radius: 0.25)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(
            AngularGradient(
              colors: [
                .red.opacity(0.75),
                .orange.opacity(0.75),
                .yellow.opacity(0.75),
                .green.opacity(0.75),
                .cyan.opacity(0.75),
                .blue.opacity(0.75),
                .purple.opacity(0.75),
                .pink.opacity(0.75),
                .red.opacity(0.75)
              ],
              center: .center
            ),
            lineWidth: 6
          )
          .blur(radius: 10)
          .opacity(0.75)
      }
  }
}

extension View {
  func rainbowGlowFrame() -> some View {
    modifier(RainbowGlowFrameModifier())
  }
}

struct LiquidGlassActionButton: View {
  let title: String
  let isDisabled: Bool
  let role: ButtonRole?
  let action: () -> Void

  init(
    _ title: String,
    isDisabled: Bool = false,
    role: ButtonRole? = nil,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.isDisabled = isDisabled
    self.role = role
    self.action = action
  }

  var body: some View {
    Button(role: role, action: action) {
      Text(title)
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(LiquidGlassButtonStyle())
    .disabled(isDisabled)
  }
}
