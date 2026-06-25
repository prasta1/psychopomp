import AVFoundation
import Speech

/// Manages live speech recognition using SFSpeechRecognizer + AVAudioEngine.
/// Streams interim transcription results so the caller can display them in real time.
@MainActor
@Observable
final class VoiceRecorder {
    private(set) var isRecording = false
    private(set) var transcript = ""

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    /// False if the on-device recognizer is unavailable (no network, unsupported locale, etc.).
    var isAvailable: Bool { recognizer?.isAvailable == true }

    init() {
        recognizer = SFSpeechRecognizer()
    }

    // MARK: - Authorization

    /// Requests both speech recognition and microphone permissions.
    /// Returns `true` only when both are granted. Safe to call multiple times.
    static func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Recording

    /// Starts live speech recognition. Interim results are streamed into `transcript`.
    func start() throws {
        guard let recognizer, recognizer.isAvailable else { return }
        reset()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                // Recognition ended naturally (final result or error) — clean up.
                if error != nil || result?.isFinal == true {
                    self.stop()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    /// Stops recording and returns the final transcript.
    @discardableResult
    func stop() -> String {
        guard isRecording else { return transcript }
        isRecording = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return transcript
    }

    // MARK: - Private

    private func reset() {
        transcript = ""
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
}
