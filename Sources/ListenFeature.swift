// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture
import SmallCharacterModel
import MusicKit

@Reducer
struct ListenFeature {
    
    struct MediaInformation: Equatable {
        var albumArt: Image
        var artistName: String
        var albumName: String
        var songName: String
        var releaseDate: String
        var appleMusicURL: URL
    }
    
    @ObservableState
    struct State: Equatable {
        var buildProgress: Double?
        
        var isLoading: Bool = true
        var mediaInformation: MediaInformation?
        var currentPlaybackTime: TimeInterval?
        var isBookmarked: Bool = false
        var isPlaying: Bool = false
        
        var musicSubscription: MusicSubscription?
        var authorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
        
        var smallCharacterModel = SmallCharacterModel.State()
        
        var modelName = "song-titles"
        var modelCohesion = 3
        
        var bundleSource: URL {
            Bundle.main.url(forResource: "song-titles", withExtension: "txt")!
        }
    }
    
    enum Action {
        case onAppear
        
        case openInAppleMusic
        case saveToFavoritesToggled
        
        case togglePlaying
        case skip
        
        case smallCharacterModel(SmallCharacterModel.Action)
    }
    
    @Dependency(\.openURL) var openURL
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // TODO: This name should come from somewhere else
                if let bundleModelURL = Bundle.main.url(forResource: "\(state.modelName)_\(state.modelCohesion)", withExtension: "penis") {
                    return .send(.smallCharacterModel(.modelLoader(.loadModelDirectly(name: state.modelName, cohesion: state.modelCohesion, source: bundleModelURL))))
                } else {
                    return .send(.smallCharacterModel(.modelLoader(.loadFromApplicationSupportOrGenerate(name: state.modelName, cohesion: state.modelCohesion, source: state.bundleSource))))
                }
            case .openInAppleMusic:
                if let url = state.mediaInformation?.appleMusicURL {
                    return .run { send in
                        await openURL(url)
                    }
                } else {
                    return .none
                }
            case .saveToFavoritesToggled:
                state.isBookmarked.toggle()
                return .none
            case .togglePlaying:
                state.isPlaying.toggle()
                return .none
            case .skip:
                return .none
                
            // Small character model
            case .smallCharacterModel(.modelLoader(.delegate(.modelLoadingFailed(let error)))):
                print(error)
                guard state.buildProgress == nil else {
                    return .none
                }
                return .send(.smallCharacterModel(.modelLoader(.loadFromApplicationSupportOrGenerate(name: state.modelName, cohesion: state.modelCohesion, source: state.bundleSource))))
            case .smallCharacterModel(.modelBuilder(.delegate(.progress(let progress)))):
                print(progress)
                state.buildProgress = progress
                return .none
            case .smallCharacterModel(.modelBuilder(.delegate(.saved))):
                state.buildProgress = nil
                return .none
            case .smallCharacterModel(.modelLoader(.delegate(.loaded))):
                state.buildProgress = nil
                return .none
            case .smallCharacterModel(.wordGenerator(.delegate(.newWord(let word)))):
                return .none
            case .smallCharacterModel:
                return .none
            }
        }
        
        Scope(state: \.smallCharacterModel, action: \.smallCharacterModel) {
            SmallCharacterModel()
        }
    }
}

import SwiftUI

struct ListenView: View {
    
    @Bindable var store: StoreOf<ListenFeature>
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let mediaInformation = store.mediaInformation {
                        mediaInformation.albumArt
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .aspectRatio(1, contentMode: .fit)
                        
                        Text(mediaInformation.artistName)
                        Text(mediaInformation.albumName)
                        Text(mediaInformation.songName)
                        Text(mediaInformation.releaseDate)
                    } else {
                        Rectangle()
                            .fill(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .aspectRatio(1, contentMode: .fit)
                    }
                    
                    if let progress = store.buildProgress {
                        ProgressView("Loading Model", value: progress)
                    } else if store.isLoading {
                        ProgressView()
                            .controlSize(.large)
                    }
                    
                    Group {
                        HStack(spacing: 40) {
                            // This is just for layout purposes
                            Button {
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.largeTitle)
                            }
                            .opacity(0)
                            
                            Button {
                                store.send(.togglePlaying)
                            } label: {
                                if store.isPlaying {
                                    Image(systemName: "pause.fill")
                                        .font(.largeTitle)
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.largeTitle)
                                }
                            }
                            
                            Button {
                                store.send(.skip)
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.largeTitle)
                            }
                        }
                        
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                    .disabled(store.isLoading)
                    
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Listen")
            .toolbar {
                ToolbarItem {
                    Button {
                        store.send(.saveToFavoritesToggled)
                    } label: {
                        if store.isBookmarked {
                            Image(systemName: "bookmark.fill")
                        } else {
                            Image(systemName: "bookmark")
                        }
                    }
                    .disabled(store.state.mediaInformation != nil)
                }
                
                ToolbarItem {
                    Button {
                        store.send(.openInAppleMusic)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .disabled(store.state.mediaInformation != nil)
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

#Preview {
    ListenView(store: .init(initialState: ListenFeature.State(), reducer: {
        ListenFeature()
    }))
}

