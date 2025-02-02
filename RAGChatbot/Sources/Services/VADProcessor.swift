import Foundation
import AVFoundation

class VADProcessor {
    // Voice Activity Detection parameters
    private let energyThreshold: Float = -30.0  // dB
    private let minSilenceDuration: TimeInterval = 1.0  // seconds
    private let vadBufferSize = 1024
    
    // State tracking
    private var lastVoiceDetectedTime: TimeInterval = 0
    private var silenceStartTime: TimeInterval?
    private var isCurrentlyTalking = false
    
    // Averaging for noise reduction
    private let smoothingFactor: Float = 0.2
    private var averageEnergy: Float = -60.0
    
    // Callback for state changes
    var onVoiceStateChanged: ((Bool) -> Void)?
    
    init() {}
    
    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = buffer.frameLength
        
        // Calculate RMS energy
        var sum: Float = 0.0
        for frame in 0..<frames {
            let sample = channelData[Int(frame)]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frames))
        let db = 20 * log10(rms)
        
        // Update average energy with smoothing
        averageEnergy = (averageEnergy * (1 - smoothingFactor)) + (db * smoothingFactor)
        
        // Detect voice activity
        let currentTime = Date().timeIntervalSince1970
        let isVoiceDetected = db > energyThreshold && db > (averageEnergy + 10)
        
        if isVoiceDetected {
            lastVoiceDetectedTime = currentTime
            silenceStartTime = nil
            
            if !isCurrentlyTalking {
                isCurrentlyTalking = true
                onVoiceStateChanged?(true)
            }
        } else {
            if silenceStartTime == nil {
                silenceStartTime = currentTime
            }
            
            // Check if silence duration exceeds threshold
            if let silenceStart = silenceStartTime,
               currentTime - silenceStart > minSilenceDuration,
               isCurrentlyTalking {
                isCurrentlyTalking = false
                onVoiceStateChanged?(false)
            }
        }
    }
    
    func reset() {
        lastVoiceDetectedTime = 0
        silenceStartTime = nil
        isCurrentlyTalking = false
        averageEnergy = -60.0
    }
}

// MARK: - Voice State Management

extension VADProcessor {
    enum VoiceState {
        case active
        case inactive
        case unknown
        
        var description: String {
            switch self {
            case .active: return "Voice Active"
            case .inactive: return "Voice Inactive"
            case .unknown: return "Unknown"
            }
        }
    }
    
    var currentState: VoiceState {
        if isCurrentlyTalking {
            return .active
        } else if silenceStartTime != nil {
            return .inactive
        } else {
            return .unknown
        }
    }
}