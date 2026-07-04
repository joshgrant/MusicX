// © BCE Labs, 2024. All rights reserved.
//

import SwiftUI

/// A first-launch welcome screen, styled after Apple's own
/// "What's New" interstitials.
struct WelcomeView: View {

    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    appIcon
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Welcome to MusicX")
                            .font(.largeTitle.bold())

                        Text("Discover songs you would never think to search for.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 28) {
                        featureRow(
                            symbol: "shuffle",
                            title: "Roll the Dice",
                            description: "MusicX dreams up search terms on its own and surfaces songs from every corner of Apple Music.")

                        featureRow(
                            symbol: "clock.fill",
                            title: "Never Lose a Find",
                            description: "Every discovery lands in your history automatically, and bookmarks keep the keepers.")

                        featureRow(
                            symbol: "square.and.arrow.up",
                            title: "Share the Gems",
                            description: "Send your favorite discoveries to friends straight from the player.")
                    }
                }
                .padding(.horizontal, 28)
            }
            .scrollIndicators(.hidden)

            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
#if os(macOS)
        .frame(width: 480, height: 620)
#endif
    }

    private var appIcon: some View {
        Image("WelcomeAppIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }

    private func featureRow(symbol: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
