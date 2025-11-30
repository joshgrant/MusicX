// © BCE Labs, 2024. All rights reserved.
//

import SwiftUI

struct SongInformation {
    var title: String
    var artist: String
    var album: String?
    var releaseDate: Date
    var duration: TimeInterval
    var genres: [String]
}

struct SongInformationView: View {
    
    var viewModel: SongInformation
    
    @State var isPlaying: Bool = false
    @State var currentDuration: TimeInterval = 0
    
    var skipBackward: () -> Void
    var togglePlaying: (Bool) -> Void
    var skipForward: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text(viewModel.title)
                .font(.title3)
                .bold()
            
            playControls
            
            Divider()
            
            albumArtistInfo
        }
    }
    
    var albumArtistInfo: some View {
        HStack {
            VStack {
                Label(viewModel.artist, systemImage: "person.fill")
                
                if let album = viewModel.album {
                    Label(album, systemImage: "music.note.square.stack")
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(viewModel.releaseDate.formatted(.dateTime.year().month(.abbreviated)))
                Text(viewModel.genres.joined(separator: ", "))
                    .italic()
            }
        }
    }
    
    var playControls: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(format(duration: currentDuration))
                Spacer()
                Text(format(duration: viewModel.duration))
            }
            .overlay(alignment: .center) {
                skipPlayButtons
            }
            
            Slider(value: $currentDuration, in: 0 ... viewModel.duration)
                .sliderThumbVisibility(.hidden)
        }
    }
    
    var skipPlayButtons: some View {
        HStack {
            Button {
                skipBackward()
            } label: {
                Image(systemName: "backward.fill")
            }
            .buttonStyle(.plain)
            
            Button {
                isPlaying.toggle()
                togglePlaying(isPlaying)
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            Button {
                skipForward()
            } label: {
                Image(systemName: "forward.fill")
            }
            .buttonStyle(.plain)
        }
    }
    
    func format(duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

#Preview {
    SongInformationView(
        viewModel: .init(
            title: "Rat Cliff",
            artist: "Light Touch",
            album: "Smart Move",
            releaseDate: .now,
            duration: 365,
            genres: ["dance", "pop"]
        ),
        skipBackward: { },
        togglePlaying: { _ in },
        skipForward: { }
    )
    .padding()
}
