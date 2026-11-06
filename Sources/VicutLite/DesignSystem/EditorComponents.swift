import AppKit
import SwiftUI

// Generic design-system pieces used by the Editor. Namespaced under `EditorKit` so they can't
// clash with `Components.swift` (built in parallel for the Queue window) until both are merged.

enum EditorKit {
  static let pressedOpacity = 0.85
  static let disabledOpacity = 0.4
}

// MARK: - Buttons

extension EditorKit {
  /// Gold call to action (Export, Replace, play).
  struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = DS.Size.footerButton

    func makeBody(configuration: Configuration) -> some View {
      HoverBody { hovering in
        configuration.label
          .dsText(DS.Typography.label)
          .foregroundStyle(DS.Color.onGold)
          .padding(.horizontal, DS.Space.s4)
          .frame(height: height)
          .background(
            RoundedRectangle(cornerRadius: DS.Radius.button)
              .fill(hovering ? DS.Color.gold400 : DS.Color.gold500)
          )
          .opacity(configuration.isPressed ? EditorKit.pressedOpacity : 1)
          .contentShape(RoundedRectangle(cornerRadius: DS.Radius.button))
      }
    }
  }

  /// Outlined secondary action (Cancel, Keep spans, toolbar toggles).
  struct GhostButtonStyle: ButtonStyle {
    var height: CGFloat = DS.Size.footerButton
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
      HoverBody { hovering in
        configuration.label
          .dsText(DS.Typography.label)
          .foregroundStyle(isActive || hovering ? DS.Color.gold300 : DS.Color.textSecondary)
          .padding(.horizontal, DS.Space.s3)
          .frame(height: height)
          .background(
            RoundedRectangle(cornerRadius: DS.Radius.button)
              .fill(isActive ? DS.Color.goldTint : (hovering ? DS.Color.bgHover : SwiftUI.Color.clear))
          )
          .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.button)
              .strokeBorder(isActive ? DS.Color.gold500 : DS.Color.borderStrong, lineWidth: DS.Size.hairline)
          )
          .opacity(configuration.isPressed ? EditorKit.pressedOpacity : 1)
          .contentShape(RoundedRectangle(cornerRadius: DS.Radius.button))
      }
    }
  }

  /// Square icon-only button; `bordered` adds the gold-soft outline used next to labels.
  struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = DS.Size.iconButton
    var isActive = false
    var bordered = false
    var tint: SwiftUI.Color = DS.Color.textSecondary

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
      HoverBody { hovering in
        configuration.label
          .font(.system(size: DS.Size.icon, weight: .semibold))
          .foregroundStyle(isActive || (hovering && isEnabled) ? DS.Color.gold300 : tint)
          .frame(width: size, height: size)
          .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
              .fill(isActive ? DS.Color.goldTint : (hovering && isEnabled ? DS.Color.bgHover : SwiftUI.Color.clear))
          )
          .overlay {
            if bordered || isActive {
              RoundedRectangle(cornerRadius: DS.Radius.sm)
                .strokeBorder(isActive ? DS.Color.gold500 : DS.Color.borderGoldSoft, lineWidth: DS.Size.hairline)
            }
          }
          .opacity(isEnabled ? (configuration.isPressed ? EditorKit.pressedOpacity : 1) : EditorKit.disabledOpacity)
          .contentShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
      }
    }
  }

  /// ButtonStyle can't hold @State, so hover lives in this small wrapper view.
  struct HoverBody<Content: View>: View {
    @ViewBuilder let content: (Bool) -> Content
    @State private var hovering = false

    var body: some View {
      content(hovering).onHover { hovering = $0 }
    }
  }
}

// MARK: - Small pieces

extension EditorKit {
  /// Square color key next to a span / category name.
  struct Swatch: View {
    let color: SwiftUI.Color
    var size: CGFloat = DS.Size.swatch

    var body: some View {
      RoundedRectangle(cornerRadius: DS.Radius.xs)
        .fill(color)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
  }

  /// Rounded label on a dark stage or inside a button (count, size limit, status).
  struct Pill: View {
    let text: String
    var foreground: SwiftUI.Color = DS.Color.textPrimary
    var fill: SwiftUI.Color = .clear
    var border: SwiftUI.Color? = DS.Color.borderGoldSoft
    var radius: CGFloat = DS.Radius.pill

    var body: some View {
      Text(text)
        .dsText(DS.Typography.micro)
        .foregroundStyle(foreground)
        .padding(.horizontal, DS.Space.s2)
        .padding(.vertical, DS.Space.s1)
        .background(RoundedRectangle(cornerRadius: radius).fill(fill))
        .overlay {
          if let border {
            RoundedRectangle(cornerRadius: radius).strokeBorder(border, lineWidth: DS.Size.hairline)
          }
        }
    }
  }

  /// Transient status message floating over content.
  struct Toast: View {
    let message: String
    let isError: Bool

    var body: some View {
      HStack(spacing: DS.Space.s2) {
        Image(systemName: "exclamationmark.circle")
          .font(.system(size: DS.Size.iconSmall, weight: .semibold))
          .foregroundStyle(isError ? DS.Color.dangerText : DS.Color.gold500)
        Text(message)
          .dsText(DS.Typography.caption)
          .foregroundStyle(DS.Color.textPrimary)
      }
      .padding(.horizontal, DS.Space.s3_5)
      .padding(.vertical, DS.Space.s2)
      .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(isError ? DS.Color.dangerBg : DS.Color.bgToast))
      .overlay(
        RoundedRectangle(cornerRadius: DS.Radius.md)
          .strokeBorder(isError ? DS.Color.dangerBorder : DS.Color.borderGold, lineWidth: DS.Size.hairline)
      )
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.updatesFrequently)
    }
  }
}

// MARK: - Menu

extension EditorKit {
  /// Raised panel holding menu items; place it with `.position` / overlays.
  struct Menu<Content: View>: View {
    var width: CGFloat = DS.Size.menuWidth
    @ViewBuilder let content: Content

    var body: some View {
      VStack(alignment: .leading, spacing: DS.Space.s0_5) {
        content
      }
      .padding(DS.Space.s1_5)
      .frame(width: width)
      .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(DS.Color.bgRaised))
      .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Color.borderGoldSoft, lineWidth: DS.Size.hairline))
      .shadow(color: DS.Color.shadow, radius: DS.Size.shadowRadius, y: DS.Size.shadowY)
    }
  }

  struct MenuHeader: View {
    let text: String

    var body: some View {
      Text(text)
        .dsText(DS.Typography.overline)
        .foregroundStyle(DS.Color.textFaint)
        .padding(.horizontal, DS.Space.s2)
        .padding(.top, DS.Space.s1_5)
        .padding(.bottom, DS.Space.s1)
    }
  }

  struct MenuDivider: View {
    var body: some View {
      Rectangle()
        .fill(DS.Color.borderDefault)
        .frame(height: DS.Size.hairline)
        .padding(.horizontal, DS.Space.s1_5)
        .padding(.vertical, DS.Space.s1)
    }
  }

  /// Menu row with optional swatch / symbol and a check mark for radio-style choices.
  struct MenuItem: View {
    let title: String
    var swatch: SwiftUI.Color?
    var systemImage: String?
    var isChecked = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
      Button(action: action) {
        HoverBody { hovering in
          HStack(spacing: DS.Space.s2) {
            if let swatch {
              Swatch(color: swatch)
            } else if let systemImage {
              Image(systemName: systemImage)
                .font(.system(size: DS.Size.iconSmall, weight: .semibold))
                .foregroundStyle(DS.Color.textSecondary)
                .frame(width: DS.Size.swatch)
            }
            Text(title)
              .dsText(DS.Typography.body)
              .foregroundStyle(DS.Color.textPrimary)
            Spacer(minLength: DS.Space.s2)
            if isChecked {
              Image(systemName: "checkmark")
                .font(.system(size: DS.Size.iconSmall, weight: .bold))
                .foregroundStyle(DS.Color.gold500)
            }
          }
          .padding(.horizontal, DS.Space.s2)
          .frame(height: DS.Size.menuItem)
          .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
              .fill(hovering && isEnabled ? DS.Color.bgHover : SwiftUI.Color.clear)
          )
          .contentShape(Rectangle())
        }
      }
      .buttonStyle(.plain)
      .disabled(!isEnabled)
      .opacity(isEnabled ? 1 : EditorKit.disabledOpacity)
      .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
  }
}

// MARK: - Dialog

extension EditorKit {
  /// Modal card on a scrim, covering whatever it overlays.
  struct Dialog<Content: View, Actions: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
      ZStack {
        DS.Color.bgScrim
          .ignoresSafeArea()
          .contentShape(Rectangle())
          // Swallow clicks so the content behind a modal dialog can't be edited.
          .onTapGesture {}
        VStack(alignment: .leading, spacing: DS.Space.s3_5) {
          Text(title)
            .dsText(DS.Typography.title)
            .foregroundStyle(DS.Color.textPrimary)
            .accessibilityAddTraits(.isHeader)
          content
          HStack(spacing: DS.Space.s2) {
            Spacer()
            actions
          }
          .padding(.top, DS.Space.s1)
        }
        .padding(DS.Space.s6)
        .frame(width: DS.Size.dialogWidth)
        .background(RoundedRectangle(cornerRadius: DS.Radius.xxl).fill(DS.Color.bgRaised))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.xxl).strokeBorder(DS.Color.borderGoldSoft, lineWidth: DS.Size.hairline))
        .shadow(color: DS.Color.shadow, radius: DS.Size.shadowRadius, y: DS.Size.shadowY)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
      }
    }
  }
}

// MARK: - Patterns

extension EditorKit {
  /// Repeating vertical bars: `bar` wide, then `gap` wide (filmstrip look).
  struct StripePattern: Shape {
    let bar: CGFloat
    let gap: CGFloat

    func path(in rect: CGRect) -> Path {
      var path = Path()
      let step = bar + gap
      guard step > 0 else { return path }
      var x = rect.minX + bar
      while x < rect.maxX {
        path.addRect(CGRect(x: x, y: rect.minY, width: min(gap, rect.maxX - x), height: rect.height))
        x += step
      }
      return path
    }
  }

  /// 45° stripes, `stripe` wide with `gap` between (measured along the horizontal).
  struct HatchPattern: Shape {
    let stripe: CGFloat
    let gap: CGFloat

    func path(in rect: CGRect) -> Path {
      var path = Path()
      let step = stripe + gap
      guard step > 0 else { return path }
      var x = rect.minX - rect.height
      while x < rect.maxX {
        path.move(to: CGPoint(x: x, y: rect.maxY))
        path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
        path.addLine(to: CGPoint(x: x + rect.height + stripe, y: rect.minY))
        path.addLine(to: CGPoint(x: x + stripe, y: rect.maxY))
        path.closeSubpath()
        x += step
      }
      return path
    }
  }
}

// MARK: - Window

extension EditorKit {
  /// Reaches the hosting NSWindow for settings SwiftUI doesn't expose on macOS 14
  /// (e.g. hiding the system title so a custom one can sit in the toolbar).
  struct WindowConfigurator: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
      let view = NSView()
      DispatchQueue.main.async { [weak view] in
        if let window = view?.window {
          configure(window)
        }
      }
      return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
  }
}
