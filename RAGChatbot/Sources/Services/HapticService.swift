import Foundation
import UIKit

class HapticService {
    static let shared = HapticService()
    
    private var impactFeedbackGenerator: UIImpactFeedbackGenerator?
    private var selectionFeedbackGenerator: UISelectionFeedbackGenerator?
    private var notificationFeedbackGenerator: UINotificationFeedbackGenerator?
    
    private init() {
        prepareHaptics()
    }
    
    private func prepareHaptics() {
        impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        
        impactFeedbackGenerator?.prepare()
        selectionFeedbackGenerator?.prepare()
        notificationFeedbackGenerator?.prepare()
    }
    
    // MARK: - Button Feedback
    
    func buttonTap() {
        impactFeedbackGenerator?.impactOccurred()
    }
    
    func buttonPress() {
        impactFeedbackGenerator?.impactOccurred(intensity: 0.8)
    }
    
    func buttonRelease() {
        impactFeedbackGenerator?.impactOccurred(intensity: 0.4)
    }
    
    // MARK: - Recording State Feedback
    
    func recordingStarted() {
        notificationFeedbackGenerator?.notificationOccurred(.success)
    }
    
    func recordingStopped() {
        notificationFeedbackGenerator?.notificationOccurred(.warning)
    }
    
    func recordingError() {
        notificationFeedbackGenerator?.notificationOccurred(.error)
    }
    
    // MARK: - Audio Level Feedback
    
    private var lastFeedbackTime: TimeInterval = 0
    private let feedbackThreshold: TimeInterval = 0.1 // Minimum time between haptic feedback
    
    func audioLevelChanged(_ level: Float) {
        let currentTime = Date().timeIntervalSince1970
        
        // Only provide feedback if enough time has passed and the level is significant
        if currentTime - lastFeedbackTime > feedbackThreshold && level > 0.7 {
            selectionFeedbackGenerator?.selectionChanged()
            lastFeedbackTime = currentTime
            
            // Prepare for next feedback
            selectionFeedbackGenerator?.prepare()
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        impactFeedbackGenerator = nil
        selectionFeedbackGenerator = nil
        notificationFeedbackGenerator = nil
    }
}