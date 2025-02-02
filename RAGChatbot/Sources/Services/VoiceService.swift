import Foundation
import Speech
import AVFoundation

protocol VoiceServiceDelegate: AnyObject {
    func voiceService(_ service: VoiceService, didRecognizeText text: String)
    func voiceService(_ service: VoiceService, didFailWithError error: Error)
    func voiceService(_ service: VoiceService, didUpdateSoundLevel level: Float)
    func voiceService(_ service: VoiceService, didDetectVoiceActivity isActive: Bool)
}

enum VoiceServiceError: Error {
    case notAuthorized
    case recognitionNotAvailable
    case audioEngineError
    case noAudioInput
    case vadError
}

class VoiceService: NSObject, SFSpeechRecognizerDelegate {
    static let shared = VoiceService()
    
    weak var delegate: VoiceServiceDelegate?
    
    // Speech recognition properties
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Speech synthesis properties
    private let synthesizer = AVSpeechSynthesizer()
    
    // Voice Activity Detection
    private let vadProcessor = VADProcessor()
    private var isRecording = false
    private var isProcessingVAD = false
    
    // Auto-stop properties
    private var autoStopTimer: Timer?
    private let maxSilenceDuration: TimeInterval = 2.0
    
    override private init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        self.speechRecognizer?.delegate = self
        self.synthesizer.delegate = self
        
        // Set up VAD callback
        vadProcessor.onVoiceStateChanged = { [weak self] isActive in
            guard let self = self else { return }
            self.handleVoiceActivityChange(isActive)
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization(completion: @escaping (Result<Void, Error>) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    completion(.success(()))
                case .denied, .restricted, .notDetermined:
                    completion(.failure(VoiceServiceError.notAuthorized))
                @unknown default:
                    completion(.failure(VoiceServiceError.notAuthorized))
                }
            }
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() {
        // Check if we're already recording
        guard !isRecording else { return }
        
        // Reset states
        recognitionTask?.cancel()
        recognitionTask = nil
        vadProcessor.reset()
        
        // Configure audio session
        do {
            try configureAudioSession()
        } catch {
            delegate?.voiceService(self, didFailWithError: error)
            return
        }
        
        // Create and configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            delegate?.voiceService(self, didFailWithError: VoiceServiceError.audioEngineError)
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio engine and recognition task
        let inputNode = audioEngine.inputNode
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            delegate?.voiceService(self, didFailWithError: VoiceServiceError.recognitionNotAvailable)
            return
        }
        
        // Set up recognition task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.stopRecording()
                self.delegate?.voiceService(self, didFailWithError: error)
                return
            }
            
            if let result = result {
                let recognizedText = result.bestTranscription.formattedString
                self.delegate?.voiceService(self, didRecognizeText: recognizedText)
            }
        }
        
        // Install tap on input node
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)
            
            // Process audio for VAD
            self.vadProcessor.processBuffer(buffer)
            
            // Calculate and report sound level
            self.processSoundLevel(buffer)
        }
        
        // Start audio engine
        do {
            try audioEngine.start()
            isRecording = true
            isProcessingVAD = true
        } catch {
            stopRecording()
            delegate?.voiceService(self, didFailWithError: error)
        }
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
        }
        
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        isRecording = false
        isProcessingVAD = false
        vadProcessor.reset()
    }
    
    // MARK: - Voice Activity Detection
    
    private func handleVoiceActivityChange(_ isActive: Bool) {
        delegate?.voiceService(self, didDetectVoiceActivity: isActive)
        
        if isActive {
            // Cancel any pending auto-stop
            autoStopTimer?.invalidate()
            autoStopTimer = nil
        } else {
            // Start auto-stop timer when voice becomes inactive
            autoStopTimer?.invalidate()
            autoStopTimer = Timer.scheduledTimer(withTimeInterval: maxSilenceDuration, repeats: false) { [weak self] _ in
                self?.stopRecording()
            }
        }
    }
    
    // MARK: - Audio Processing
    
    private func processSoundLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = buffer.frameLength
        
        var sum: Float = 0.0
        for frame in 0..<frames {
            let sample = channelData[Int(frame)]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frames))
        let db = 20 * log10(rms)
        let normalizedLevel = max(0.0, min(1.0, (db + 50) / 50))
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.voiceService(self, didUpdateSoundLevel: normalizedLevel)
        }
    }
    
    // MARK: - Speech Synthesis
    
    func speak(_ text: String, completion: (() -> Void)? = nil) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8
        
        synthesizer.speak(utterance)
    }
    
    // MARK: - Private Helpers
    
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Handle speech completion if needed
    }
}