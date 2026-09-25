#if os(iOS)
    import MediaPlayer
    import Testing

    @testable import MediaBridge

    @MainActor
    @Suite("Media picker")
    struct MediaPickerTests {

        @Suite("Given picker options")
        @MainActor
        struct Configuration {
            @Test("When the defaults are used, then it picks several songs, including cloud and protected ones")
            func defaults() {
                let picker = MediaPicker(onPick: { _ in }).makePicker()

                #expect(picker.mediaTypes == .music)
                #expect(picker.allowsPickingMultipleItems)
                #expect(picker.showsCloudItems)
                #expect(picker.showsItemsWithProtectedAssets)
                #expect(picker.prompt == nil)
            }

            @Test("When options are set, then the MediaPlayer picker gets them")
            func custom() {
                let picker = MediaPicker(
                    mediaTypes: .podcast,
                    allowsMultipleSelection: false,
                    showsCloudItems: false,
                    showsItemsWithProtectedAssets: false,
                    prompt: "Pick a podcast",
                    onPick: { _ in }
                ).makePicker()

                #expect(picker.mediaTypes == .podcast)
                #expect(!picker.allowsPickingMultipleItems)
                #expect(!picker.showsCloudItems)
                #expect(!picker.showsItemsWithProtectedAssets)
                #expect(picker.prompt == "Pick a podcast")
            }

            @Test("When options change while it's showing, then the picker is updated")
            func updates() {
                let picker = MediaPicker(onPick: { _ in }).makePicker()

                MediaPicker(allowsMultipleSelection: false, showsCloudItems: false, prompt: "Pick one", onPick: { _ in })
                    .configure(picker)

                #expect(!picker.allowsPickingMultipleItems)
                #expect(!picker.showsCloudItems)
                #expect(picker.prompt == "Pick one")
            }
        }

        @Suite("Given the picker is showing")
        @MainActor
        struct Delegate {
            @Test("When songs are picked, then onPick gets them in order")
            func picks() {
                var picked: [Song] = []
                let items = [StubMediaItem.song("B"), StubMediaItem.song("A")]
                let picker = MediaPicker(onPick: { picked = $0 })
                let coordinator = picker.makeCoordinator()

                coordinator.mediaPicker(picker.makePicker(), didPickMediaItems: MPMediaItemCollection(items: items))

                #expect(picked.map(\.title) == ["B", "A"])
            }

            @Test("When cancelled, then onCancel runs and onPick doesn't")
            func cancels() {
                var picked = false
                var cancelled = false
                let picker = MediaPicker(onPick: { _ in picked = true }, onCancel: { cancelled = true })

                picker.makeCoordinator().mediaPickerDidCancel(picker.makePicker())

                #expect(cancelled)
                #expect(!picked)
            }
        }
    }
#endif
