import Foundation
import Speech
import AVFoundation

enum VoiceServiceError: Error {
    case notAuthorized
    case recognitionNotAvailable
    case audioEngineError
    case noAudioInput
}

protocol VoiceServiceDelegate: AnyObject {
    func voiceService(_ service: VoiceService, didRecognizeText text: String)
    func voiceService(_ service: VoiceService, didFailWithError error: Error)
    func voiceService(_ service: VoiceService, didUpdateSoundLevel level: Float)
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
    private var isRecording = false
    
    // Sound level monitoring
    private let LEVEL_LOWPASS_TRIG: Float32 = 0.30
    private var previousLevel: Float32 = 0.0
    
    override private init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        self.speechRecognizer?.delegate = self
        synthesizer.delegate = self
    }
    
    // MARK: - Authorization
    
    func requestAuthorization(completion: @escaping (Result<Void, Error>) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    completion(.success(()))
                case .denied:
                    completion(.failure(VoiceServiceError.notAuthorized))
                case .restricted:
                    completion(.failure(VoiceServiceError.notAuthorized))
                case .notDetermined:
                    completion(.failure(VoiceServiceError.notAuthorized))
                @unknown default:
                    completion(.failure(VoiceServiceError.notAuthorized))
                }
            }
        }
    }
    
    // MARK: - Speech Recognition
    
    func startRecording() {
        // Check if we're already recording
        guard !isRecording else { return }
        
        // Reset any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
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
            
            // Calculate sound level
            self.processSoundLevel(buffer)
        }
        
        // Start audio engine
        do {
            try audioEngine.start()
            isRecording = true
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
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
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
    
    // MARK: - Private Helper Methods
    
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func processSoundLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = buffer.frameLength
        
        var sumSquares: Float32 = 0.0
        for frame in 0..<frames {
            let sample = channelData[Int(frame)]
            sumSquares += sample * sample
        }
        
        let avgPower = 10 * log10f(sumSquares / Float32(frames))
        let level = max(0.0, (avgPower + 50) / 50) // Normalize to 0-1
        
        // Apply low-pass filter
        let smoothedLevel = previousLevel * LEVEL_LOWPASS_TRIG + level * (1.0 - LEVEL_LOWPASS_TRIG)
        previousLevel = smoothedLevel
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.voiceService(self, didUpdateSoundLevel: smoothedLevel)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Handle speech completion if needed
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        // Handle speech pause if needed
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        // Handle speech continuation if needed
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Handle speech cancellation if needed
    }
}