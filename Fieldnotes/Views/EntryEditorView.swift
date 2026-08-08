import AVFoundation
import PhotosUI
import Speech
import SwiftData
import SwiftUI
import UIKit

struct EmotionOption: Identifiable, Hashable {
    let id: String
    let emoji: String
    let label: String

    init(_ emoji: String, _ label: String) {
        self.id = emoji
        self.emoji = emoji
        self.label = label
    }
}

private let emotionOptions: [EmotionOption] = [
    EmotionOption("🙂", "Joy"),
    EmotionOption("🕯️", "Peace"),
    EmotionOption("😤", "Frustration"),
    EmotionOption("😢", "Sadness"),
    EmotionOption("✨", "Beauty"),
    EmotionOption("💡", "Inspiration"),
    EmotionOption("❓", "Uncertainty")
]

struct PhotoSelectionState {
    private(set) var data: Data?
    private(set) var errorMessage: String?
    private(set) var isLoading = false
    private(set) var loadRequestID: UUID?

    var isReady: Bool {
        !isLoading && errorMessage == nil && data != nil
    }

    mutating func beginLibraryLoad() -> UUID {
        let requestID = UUID()
        data = nil
        errorMessage = nil
        isLoading = true
        loadRequestID = requestID
        return requestID
    }

    mutating func finishLibraryLoad(with data: Data?, requestID: UUID) {
        guard loadRequestID == requestID else { return }

        isLoading = false
        guard let data else {
            errorMessage = "The selected image could not be loaded."
            return
        }

        self.data = data
    }

    mutating func failLibraryLoad(requestID: UUID) {
        guard loadRequestID == requestID else { return }
        data = nil
        isLoading = false
        errorMessage = "The selected image could not be loaded."
    }

    mutating func cancelLibraryLoad() {
        loadRequestID = nil
        isLoading = false
        errorMessage = nil
    }

    mutating func selectCameraPhoto(_ data: Data) {
        loadRequestID = nil
        isLoading = false
        errorMessage = nil
        self.data = data
    }

    mutating func clear() {
        cancelLibraryLoad()
        data = nil
    }
}

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var noteText = ""
    @State private var selectedEmoji: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoSelection = PhotoSelectionState()
    @State private var saveErrorMessage = ""
    @State private var isShowingSaveError = false
    @State private var isSaving = false
    @State private var isShowingCamera = false
    @State private var dictationBaseText = ""
    @StateObject private var speechTranscriber = SpeechTranscriber()

    private let characterLimit = 240

    private var trimmedNote: String {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedNote.isEmpty && isSelectedPhotoReady && !isSaving
    }

    private var isSelectedPhotoReady: Bool {
        guard selectedPhotoItem != nil else { return true }
        return photoSelection.isReady
    }

    var body: some View {
        NavigationStack {
            Form {
                noteEditor
                photoSection
                feelingSection
            }
            .navigationTitle("New Fieldnote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            loadPhoto(from: newItem)
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker(onCapture: acceptCapturedPhoto)
                .ignoresSafeArea()
        }
        .alert("Fieldnote wasn’t saved", isPresented: $isShowingSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private var noteEditor: some View {
        Section {
            HStack {
                Label(Date().fieldTimestamp, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(noteText.count)/\(characterLimit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(noteText.count > characterLimit ? .red : .secondary)
            }

            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text("What did you notice?")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $noteText)
                    .frame(minHeight: 190)
                    .onChange(of: noteText) { _, newValue in
                        if newValue.count > characterLimit {
                            noteText = String(newValue.prefix(characterLimit))
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    VoiceNoteButton(
                        isRecording: speechTranscriber.isRecording,
                        isAvailable: speechTranscriber.canRecord,
                        startAction: startDictation,
                        stopAction: stopDictation
                    )

                    Text(speechTranscriber.isRecording ? "Listening..." : "Hold to dictate")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(speechTranscriber.isRecording ? Color.accentColor : Color.secondary)
                        .animation(.easeInOut(duration: 0.2), value: speechTranscriber.isRecording)

                    Spacer()
                }

                if let errorMessage = speechTranscriber.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Observation")
        }
        .onChange(of: speechTranscriber.transcript) { _, transcript in
            applyDictationTranscript(transcript)
        }
        .onDisappear {
            speechTranscriber.stopRecording()
        }
    }

    private var photoSection: some View {
        Section {
            photoPicker
        } header: {
            Label(photoSelection.data == nil ? "Photo" : "Photo attached", systemImage: photoSelection.data == nil ? "camera" : "checkmark.circle")
        } footer: {
            if photoSelection.data == nil {
                Text("Optional. One image keeps the note light.")
            }
        }
    }

    private var feelingSection: some View {
        Section {
            EmotionPicker(selectedEmoji: $selectedEmoji)
        } header: {
            Label(selectedEmoji == nil ? "Feeling" : "Feeling \(selectedEmoji ?? "")", systemImage: selectedEmoji == nil ? "face.smiling" : "checkmark.circle")
        }
    }

    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if let selectedPhotoData = photoSelection.data, let image = UIImage(data: selectedPhotoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            clearSelectedPhoto()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.primary)
                        }
                        .padding(8)
                        .accessibilityLabel("Remove photo")
                    }
            }

            if photoSelection.isLoading {
                ProgressView("Preparing photo…")
                    .font(.footnote)
            }

            if let photoLoadError = photoSelection.errorMessage {
                Text(photoLoadError)
                    .font(.footnote)
                    .foregroundStyle(.red)

                Button("Remove photo", role: .destructive) {
                    clearSelectedPhoto()
                }
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else {
            photoSelection.cancelLibraryLoad()
            return
        }

        let requestID = photoSelection.beginLibraryLoad()

        Task {
            do {
                let data = try await item.loadTransferable(type: Data.self)
                photoSelection.finishLibraryLoad(with: data, requestID: requestID)
            } catch {
                photoSelection.failLibraryLoad(requestID: requestID)
            }
        }
    }

    private func acceptCapturedPhoto(_ data: Data) {
        photoSelection.cancelLibraryLoad()
        selectedPhotoItem = nil
        photoSelection.selectCameraPhoto(data)
    }

    private func clearSelectedPhoto() {
        photoSelection.clear()
        selectedPhotoItem = nil
    }

    private func save() {
        guard canSave else { return }
        isSaving = true

        Task { @MainActor in
            do {
                let persistence = FieldnotePersistenceStore(modelContainer: modelContext.container)
                _ = try await persistence.save(
                    text: trimmedNote,
                    emoji: selectedEmoji,
                    photoData: photoSelection.data
                )
                dismiss()
            } catch {
                if error is FieldnotesArchiveError {
                    saveErrorMessage = "Your draft is still here. \(error.localizedDescription)"
                } else {
                    saveErrorMessage = "Your draft is still here. Check available storage and try again."
                }
                isShowingSaveError = true
                isSaving = false
            }
        }
    }

    private func startDictation() {
        guard !speechTranscriber.isRecording else { return }

        dictationBaseText = noteText

        Task {
            await speechTranscriber.startRecording()
        }
    }

    private func stopDictation() {
        speechTranscriber.stopRecording()
    }

    private func applyDictationTranscript(_ transcript: String) {
        guard speechTranscriber.isRecording || !transcript.isEmpty else { return }

        let separator = dictationBaseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : " "
        let combinedText = dictationBaseText + separator + transcript
        noteText = String(combinedText.prefix(characterLimit))
    }
}

struct VoiceNoteButton: View {
    let isRecording: Bool
    let isAvailable: Bool
    let startAction: () -> Void
    let stopAction: () -> Void

    @State private var isPressing = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.headline)

            Text(isRecording ? "Release" : "Voice")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(isRecording ? .white : .primary)
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(
            isRecording ? Color.accentColor : Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(.separator).opacity(isRecording ? 0 : 0.6), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .opacity(isAvailable ? 1 : 0.55)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isAvailable, !isPressing else { return }
                    isPressing = true
                    startAction()
                }
                .onEnded { _ in
                    guard isPressing else { return }
                    isPressing = false
                    stopAction()
                }
        )
        .accessibilityLabel("Voice dictation")
        .accessibilityHint(isAvailable ? "Hold to record a fieldnote, then release to transcribe it." : "Speech recognition is unavailable.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            if isRecording {
                stopAction()
            } else if isAvailable {
                startAction()
            }
        }
    }
}

@MainActor
final class SpeechTranscriber: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var canRecord: Bool {
        (speechRecognizer?.isAvailable ?? false) && (speechRecognizer?.supportsOnDeviceRecognition ?? false)
    }

    func startRecording() async {
        guard !isRecording else { return }

        errorMessage = nil
        transcript = ""

        guard await requestPermissions() else { return }

        recognitionTask?.cancel()
        recognitionTask = nil

        guard speechRecognizer?.supportsOnDeviceRecognition == true else {
            errorMessage = "On-device dictation is not available on this device."
            return
        }

        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "The microphone could not be started."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            errorMessage = "The microphone could not be started."
            return
        }

        isRecording = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }

                if error != nil || result?.isFinal == true {
                    self.stopRecording()
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording || audioEngine.isRunning else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            errorMessage = "Speech recognition needs permission in Settings."
            return false
        }

        let microphoneAllowed = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }

        guard microphoneAllowed else {
            errorMessage = "Microphone access needs permission in Settings."
            return false
        }

        return true
    }
}

struct EmotionPicker: View {
    @Binding var selectedEmoji: String?

    var body: some View {
        Picker("Emotion signal", selection: emotionSelection) {
            Text("None").tag(Self.noSelection)

            ForEach(emotionOptions) { option in
                Text("\(option.emoji) \(option.label)")
                    .tag(option.id)
            }
        }
    }

    private static let noSelection = "none"

    private var emotionSelection: Binding<String> {
        Binding(
            get: { selectedEmoji ?? Self.noSelection },
            set: { selectedEmoji = $0 == Self.noSelection ? nil : $0 }
        )
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onCapture: (Data) -> Void
        private let dismiss: DismissAction

        init(onCapture: @escaping (Data) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.86) {
                onCapture(data)
            }

            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
