import SwiftUI

enum Palette {
    static let paper = Color(red: 0.965, green: 0.949, blue: 0.925)
    static let paperDeep = Color(red: 0.933, green: 0.910, blue: 0.875)
    static let ink = Color(red: 0.145, green: 0.125, blue: 0.110)
    static let muted = Color(red: 0.42, green: 0.38, blue: 0.34)
    static let faint = Color(red: 0.62, green: 0.57, blue: 0.52)
    static let line = Color(red: 0.84, green: 0.80, blue: 0.74)
    static let accent = Color(red: 0.62, green: 0.18, blue: 0.16)
    static let moss = Color(red: 0.29, green: 0.36, blue: 0.27)
    static let card = Color.white.opacity(0.78)
}

enum Face {
    static func display(_ size: CGFloat) -> Font { .custom("Songti SC", size: size) }
}

enum Clock {
    static func short(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.accent.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .opacity(isEnabled ? 1 : 0.4)
    }
}

struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.5 : 0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            )
    }
}

struct Chip: View {
    var title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Palette.accent : Palette.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? Palette.accent.opacity(0.12) : Color.white.opacity(0.45))
                )
        }
        .buttonStyle(.plain)
    }
}

struct SectionLabel: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(Palette.muted)
    }
}

struct FitPhoto: View {
    var image: NSImage?
    var empty: String

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Text(empty)
                .font(.system(size: 12))
                .foregroundStyle(Palette.faint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
