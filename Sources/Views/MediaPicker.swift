#if os(iOS)
    import MediaPlayer
    import SwiftUI

    /// The system media picker, for letting people choose songs from their library.
    ///
    /// The picker doesn't dismiss itself: dismiss it in `onPick` and `onCancel`, or use
    /// the `mediaPicker(isPresented:)` view modifier,
    /// which does it for you. People can pick without granting library access first.
    ///
    /// ```swift
    /// .fullScreenCover(isPresented: $isPicking) {
    ///     MediaPicker(onPick: { songs in
    ///         queue = songs
    ///         isPicking = false
    ///     }, onCancel: {
    ///         isPicking = false
    ///     })
    ///     .ignoresSafeArea()
    /// }
    /// ```
    public struct MediaPicker: UIViewControllerRepresentable {
        private let mediaTypes: MPMediaType
        private let allowsMultipleSelection: Bool
        private let showsCloudItems: Bool
        private let showsItemsWithProtectedAssets: Bool
        private let prompt: String?
        private let onPick: ([Song]) -> Void
        private let onCancel: () -> Void

        /// - Parameters:
        ///   - mediaTypes: The kinds of media to offer
        ///   - allowsMultipleSelection: Whether people can pick more than one item
        ///   - showsCloudItems: Whether to offer items that aren't downloaded
        ///   - showsItemsWithProtectedAssets: Whether to offer DRM-protected items, which
        ///     `AVPlayer` can't play
        ///   - prompt: Text shown above the picker's navigation bar buttons
        ///   - onPick: Receives the picked songs, in the order they were picked
        ///   - onCancel: Runs when people tap Cancel
        public init(
            mediaTypes: MPMediaType = .music,
            allowsMultipleSelection: Bool = true,
            showsCloudItems: Bool = true,
            showsItemsWithProtectedAssets: Bool = true,
            prompt: String? = nil,
            onPick: @escaping ([Song]) -> Void,
            onCancel: @escaping () -> Void = {}
        ) {
            self.mediaTypes = mediaTypes
            self.allowsMultipleSelection = allowsMultipleSelection
            self.showsCloudItems = showsCloudItems
            self.showsItemsWithProtectedAssets = showsItemsWithProtectedAssets
            self.prompt = prompt
            self.onPick = onPick
            self.onCancel = onCancel
        }

        public func makeUIViewController(context: Context) -> MPMediaPickerController {
            let picker = makePicker()
            picker.delegate = context.coordinator
            return picker
        }

        public func updateUIViewController(_ picker: MPMediaPickerController, context: Context) {
            context.coordinator.onPick = onPick
            context.coordinator.onCancel = onCancel
        }

        public func makeCoordinator() -> Coordinator {
            Coordinator(onPick: onPick, onCancel: onCancel)
        }

        func makePicker() -> MPMediaPickerController {
            let picker = MPMediaPickerController(mediaTypes: mediaTypes)
            picker.allowsPickingMultipleItems = allowsMultipleSelection
            picker.showsCloudItems = showsCloudItems
            picker.showsItemsWithProtectedAssets = showsItemsWithProtectedAssets
            picker.prompt = prompt
            return picker
        }

        /// Forwards the picker's delegate callbacks to `onPick` and `onCancel`.
        public final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
            var onPick: ([Song]) -> Void
            var onCancel: () -> Void

            init(onPick: @escaping ([Song]) -> Void, onCancel: @escaping () -> Void) {
                self.onPick = onPick
                self.onCancel = onCancel
            }

            public func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
                onPick(mediaItemCollection.items.map(Song.init))
            }

            public func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
                onCancel()
            }
        }
    }

    extension View {
        /// Presents the system media picker in a sheet and dismisses it when people pick or cancel.
        ///
        /// ```swift
        /// Button("Add Songs") { isPicking = true }
        ///     .mediaPicker(isPresented: $isPicking) { songs in
        ///         Task { try await library.add(songs, to: playlist) }
        ///     }
        /// ```
        ///
        /// - Parameters:
        ///   - isPresented: Whether the picker is showing; set back to `false` when it closes
        ///   - mediaTypes: The kinds of media to offer
        ///   - allowsMultipleSelection: Whether people can pick more than one item
        ///   - prompt: Text shown above the picker's navigation bar buttons
        ///   - onPick: Receives the picked songs, in the order they were picked
        public func mediaPicker(
            isPresented: Binding<Bool>,
            mediaTypes: MPMediaType = .music,
            allowsMultipleSelection: Bool = true,
            prompt: String? = nil,
            onPick: @escaping ([Song]) -> Void
        ) -> some View {
            sheet(isPresented: isPresented) {
                MediaPicker(
                    mediaTypes: mediaTypes,
                    allowsMultipleSelection: allowsMultipleSelection,
                    prompt: prompt,
                    onPick: { songs in
                        isPresented.wrappedValue = false
                        onPick(songs)
                    },
                    onCancel: { isPresented.wrappedValue = false }
                )
                .ignoresSafeArea()
            }
        }
    }
#endif
