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

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var noteText = ""
    @State private var selectedEmoji: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var photoLoadError: String?
    @State private var isShowingCamera = false
    @State private var dictationBaseText = ""
    @StateObject private var speechTranscriber = SpeechTranscriber()

    private let characterLimit = 240

    private var trimmedNote: String {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedNote.isEmpty
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
            CameraPicker(selectedPhotoData: $selectedPhotoData)
                .ignoresSafeArea()
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
            Label(selectedPhotoData == nil ? "Photo" : "Photo attached", systemImage: selectedPhotoData == nil ? "camera" : "checkmark.circle")
        } footer: {
            if selectedPhotoData == nil {
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

            if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            self.selectedPhotoData = nil
                            selectedPhotoItem = nil
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

            if let photoLoadError {
                Text(photoLoadError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        photoLoadError = nil

        guard let item else {
            selectedPhotoData = nil
            return
        }

        Task {
            do {
                selectedPhotoData = try await item.loadTransferable(type: Data.self)
            } catch {
                selectedPhotoData = nil
                photoLoadError = "The selected image could not be loaded."
            }
        }
    }

    private func save() {
        let entry = Fieldnote(text: trimmedNote, emoji: selectedEmoji, photoData: selectedPhotoData)
        modelContext.insert(entry)
        dismiss()
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
    @Binding var selectedPhotoData: Data?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedPhotoData: $selectedPhotoData, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding private var selectedPhotoData: Data?
        private let dismiss: DismissAction

        init(selectedPhotoData: Binding<Data?>, dismiss: DismissAction) {
            _selectedPhotoData = selectedPhotoData
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                selectedPhotoData = image.jpegData(compressionQuality: 0.86)
            }

            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
