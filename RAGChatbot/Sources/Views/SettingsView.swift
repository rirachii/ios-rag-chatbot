import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = UserSettings.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Haptic Feedback")) {
                    Toggle("Enable Haptic Feedback", isOn: $settings.isHapticEnabled)
                    
                    if settings.isHapticEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Button Feedback Intensity")
                            Picker("Button Feedback Intensity", selection: $settings.buttonHapticIntensity) {
                                ForEach(UserSettings.HapticIntensity.allCases, id: \.self) { intensity in
                                    Text(intensity.rawValue)
                                        .tag(intensity)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Audio Level Feedback")
                            Picker("Audio Level Feedback", selection: $settings.audioLevelHapticIntensity) {
                                ForEach(UserSettings.HapticIntensity.allCases, id: \.self) { intensity in
                                    Text(intensity.rawValue)
                                        .tag(intensity)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Audio Level Threshold")
                            HStack {
                                Slider(
                                    value: $settings.audioLevelHapticThreshold,
                                    in: 0.1...0.9,
                                    step: 0.1
                                )
                                Text("\(Int(settings.audioLevelHapticThreshold * 100))%")
                                    .frame(width: 50)
                            }
                            Text("Higher threshold means less frequent feedback")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section(header: Text("Preview")) {
                    Button("Test Button Feedback") {
                        testButtonFeedback()
                    }
                    .disabled(!settings.isHapticEnabled)
                }
                
                Section(footer: Text("Haptic feedback provides tactile responses to your interactions with the app.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private func testButtonFeedback() {
        let hapticService = HapticService.shared
        
        // Simulate button press and release
        hapticService.buttonPress()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            hapticService.buttonRelease()
        }
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif