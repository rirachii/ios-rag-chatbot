import Foundation

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    private let defaults = UserDefaults.standard
    
    // Haptic Feedback Settings
    @Published var isHapticEnabled: Bool {
        didSet {
            defaults.set(isHapticEnabled, forKey: Keys.isHapticEnabled)
        }
    }
    
    @Published var buttonHapticIntensity: HapticIntensity {
        didSet {
            defaults.set(buttonHapticIntensity.rawValue, forKey: Keys.buttonHapticIntensity)
        }
    }
    
    @Published var audioLevelHapticIntensity: HapticIntensity {
        didSet {
            defaults.set(audioLevelHapticIntensity.rawValue, forKey: Keys.audioLevelHapticIntensity)
        }
    }
    
    @Published var audioLevelHapticThreshold: Float {
        didSet {
            defaults.set(audioLevelHapticThreshold, forKey: Keys.audioLevelHapticThreshold)
        }
    }
    
    private init() {
        // Load saved settings or use defaults
        self.isHapticEnabled = defaults.bool(forKey: Keys.isHapticEnabled, defaultValue: true)
        
        self.buttonHapticIntensity = HapticIntensity(rawValue: defaults.string(forKey: Keys.buttonHapticIntensity) ?? "") ?? .medium
        
        self.audioLevelHapticIntensity = HapticIntensity(rawValue: defaults.string(forKey: Keys.audioLevelHapticIntensity) ?? "") ?? .light
        
        self.audioLevelHapticThreshold = defaults.float(forKey: Keys.audioLevelHapticThreshold, defaultValue: 0.3)
    }
    
    // MARK: - Types
    
    enum HapticIntensity: String, CaseIterable {
        case off = "Off"
        case light = "Light"
        case medium = "Medium"
        case heavy = "Heavy"
        
        var uiImpactStyle: UIImpactFeedbackGenerator.FeedbackStyle? {
            switch self {
            case .off: return nil
            case .light: return .light
            case .medium: return .medium
            case .heavy: return .heavy
            }
        }
    }
    
    // MARK: - UserDefaults Keys
    
    private struct Keys {
        static let isHapticEnabled = "isHapticEnabled"
        static let buttonHapticIntensity = "buttonHapticIntensity"
        static let audioLevelHapticIntensity = "audioLevelHapticIntensity"
        static let audioLevelHapticThreshold = "audioLevelHapticThreshold"
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            set(defaultValue, forKey: key)
        }
        return bool(forKey: key)
    }
    
    func float(forKey key: String, defaultValue: Float) -> Float {
        if object(forKey: key) == nil {
            set(defaultValue, forKey: key)
        }
        return float(forKey: key)
    }
}