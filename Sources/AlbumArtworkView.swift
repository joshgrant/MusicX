// © BCE Labs, 2024. All rights reserved.
//

import SwiftUI

/// Loads album artwork with the persistence `AsyncImage` lacks: a failed
/// fetch (flaky network, app suspended mid-load, tab switched away) is
/// retried with backoff, and again whenever the app returns to the
/// foreground — so artwork always catches up with the song details.
struct AlbumArtworkView: View {

    let url: URL?

    @Environment(\.scenePhase) private var scenePhase

    @State private var image: Image?
    @State private var loadedURL: URL?
    @State private var attempt = 0

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .aspectRatio(1, contentMode: .fit)
            } else {
                Image("LoadingView")
                    .resizable()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .aspectRatio(1, contentMode: .fit)
                    .redacted(reason: .placeholder)
            }
        }
        .task(id: "\(attempt)|\(url?.absoluteString ?? "")") {
            await load()
        }
        .onChange(of: scenePhase) { _, newValue in
            // A fetch that ran while the app was suspended can fail for
            // good; kick off a fresh one as soon as we're back.
            if newValue == .active, image == nil || loadedURL != url {
                attempt += 1
            }
        }
    }

    private func load() async {
        guard let url else {
            image = nil
            loadedURL = nil
            return
        }

        if loadedURL == url, image != nil { return }

        // Don't show the previous song's artwork next to the new song's
        // details while the new artwork loads.
        image = nil

        // Catalog artwork is immutable, so a cached copy is always right.
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        for delay in [0.0, 1.0, 3.0] {
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }

            guard let (data, _) = try? await URLSession.shared.data(for: request) else {
                continue
            }

#if os(iOS)
            guard let platformImage = UIImage(data: data) else { continue }
            image = Image(uiImage: platformImage)
#else
            guard let platformImage = NSImage(data: data) else { continue }
            image = Image(nsImage: platformImage)
#endif
            loadedURL = url
            return
        }
    }
}

#Preview {
    AlbumArtworkView(url: URL(string: "https://www.udiscovermusic.com/wp-content/uploads/2015/10/Flamin-Groovies-1024x1024.jpg"))
        .padding()
}
