import Foundation
import UIKit

class HapticService {
    static let shared = HapticService()
    
    private var lightImpactGenerator: UIImpactFeedbackGenerator?
    private var mediumImpactGenerator: UIImpactFeedbackGenerator?
    private var heavyImpactGenerator: UIImpactFeedbackGenerator?
    private var selectionFeedbackGenerator: UISelectionFeedbackGenerator?
    private var notificationFeedbackGenerator: UINotificationFeedbackGenerator?
    
    private let settings = UserSettings.shared
    
    private init() {
        prepareHaptics()
    }
    
    private func prepareHaptics() {
        lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
        mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
        heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
        selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        notificationFeedbackGenerator = UINotificationFeedbackGenerator()
        
        lightImpactGenerator?.prepare()
        mediumImpactGenerator?.prepare()
        heavyImpactGenerator?.prepare()
        selectionFeedbackGenerator?.prepare()
        notificationFeedbackGenerator?.prepare()
    }
    
    // MARK: - Button Feedback
    
    private func getImpactGenerator(for intensity: UserSettings.HapticIntensity) -> UIImpactFeedbackGenerator? {
        switch intensity {
        case .light: return lightImpactGenerator
        case .medium: return mediumImpactGenerator
        case .heavy: return heavyImpactGenerator
        case .off: return nil
        }
    }
    
    func buttonPress() {
        guard settings.isHapticEnabled else { return }
        getImpactGenerator(for: settings.buttonHapticIntensity)?.impactOccurred(intensity: 0.8)
    }
    
    func buttonRelease() {
        guard settings.isHapticEnabled else { return }
        getImpactGenerator(for: settings.buttonHapticIntensity)?.impactOccurred(intensity: 0.4)
    }
    
    // MARK: - Recording State Feedback
    
    func recordingStarted() {
        guard settings.isHapticEnabled else { return }
        notificationFeedbackGenerator?.notificationOccurred(.success)
    }
    
    func recordingStopped() {
        guard settings.isHapticEnabled else { return }
        notificationFeedbackGenerator?.notificationOccurred(.warning)
    }
    
    func recordingError() {
        guard settings.isHapticEnabled else { return }
        notificationFeedbackGenerator?.notificationOccurred(.error)
    }
    
    // MARK: - Audio Level Feedback
    
    private var lastFeedbackTime: TimeInterval = 0
    private let feedbackThreshold: TimeInterval = 0.1
    
    func audioLevelChanged(_ level: Float) {
        guard settings.isHapticEnabled,
              settings.audioLevelHapticIntensity != .off,
              level > settings.audioLevelHapticThreshold else {
            return
        }
        
        let currentTime = Date().timeIntervalSince1970
        guard currentTime - lastFeedbackTime > feedbackThreshold else {
            return
        }
        
        getImpactGenerator(for: settings.audioLevelHapticIntensity)?.impactOccurred(intensity: CGFloat(level))
        lastFeedbackTime = currentTime
        
        // Prepare for next feedback
        prepareHaptics()
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        lightImpactGenerator = nil
        mediumImpactGenerator = nil
        heavyImpactGenerator = nil
        selectionFeedbackGenerator = nil
        notificationFeedbackGenerator = nil
    }
}