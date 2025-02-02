import SwiftUI

struct LiveAudioView: View {
    @StateObject private var audioViewModel = LiveAudioViewModel()
    @GestureState private var isPressed = false
    
    var body: some View {
        VStack(spacing: 20) {
            AudioWaveformView(soundLevel: $audioViewModel.soundLevel)
                .padding()
            
            // Voice Activity Indicator
            VoiceActivityIndicator(isActive: audioViewModel.isVoiceActive)
                .frame(height: 30)
            
            // Recording Button
            Button(action: {
                audioViewModel.isRecording ? audioViewModel.stopRecording() : audioViewModel.startRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(audioViewModel.isRecording ? Color.red : Color.blue)
                        .frame(width: 70, height: 70)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                    
                    Image(systemName: audioViewModel.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { value, state, _ in
                        state = true
                        HapticService.shared.buttonPress()
                    }
                    .onEnded { _ in
                        HapticService.shared.buttonRelease()
                    }
            )
            
            // Status Text
            Text(audioViewModel.statusText)
                .font(.caption)
                .foregroundColor(.secondary)
                .animation(.easeInOut, value: audioViewModel.statusText)
        }
        .padding()
    }
}

// MARK: - Voice Activity Indicator
struct VoiceActivityIndicator: View {
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(isActive ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .scaleEffect(isActive ? 1.0 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.3).delay(Double(index) * 0.1),
                        value: isActive
                    )
            }
        }
        .overlay(
            Text(isActive ? "Voice Detected" : "Listening")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 20)
        )
    }
}

// MARK: - View Model
class LiveAudioViewModel: NSObject, ObservableObject {
    @Published var soundLevel: Float = 0.0
    @Published var isRecording: Bool = false
    @Published var isVoiceActive: Bool = false
    @Published var statusText: String = "Ready to record"
    
    private let voiceService = VoiceService.shared
    
    override init() {
        super.init()
        voiceService.delegate = self
    }
    
    func startRecording() {
        voiceService.startRecording()
        isRecording = true
        statusText = "Recording started..."
    }
    
    func stopRecording() {
        voiceService.stopRecording()
        isRecording = false
        isVoiceActive = false
        statusText = "Recording stopped"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.statusText = "Ready to record"
        }
    }
}

// MARK: - VoiceServiceDelegate
extension LiveAudioViewModel: VoiceServiceDelegate {
    func voiceService(_ service: VoiceService, didRecognizeText text: String) {
        statusText = "Recognized: \(text)"
    }
    
    func voiceService(_ service: VoiceService, didFailWithError error: Error) {
        statusText = "Error: \(error.localizedDescription)"
        isRecording = false
        isVoiceActive = false
    }
    
    func voiceService(_ service: VoiceService, didUpdateSoundLevel level: Float) {
        soundLevel = level
    }
    
    func voiceService(_ service: VoiceService, didDetectVoiceActivity isActive: Bool) {
        DispatchQueue.main.async {
            self.isVoiceActive = isActive
            if isActive {
                self.statusText = "Voice detected"
            } else {
                self.statusText = "Listening..."
            }
        }
    }
}

#if DEBUG
struct LiveAudioView_Previews: PreviewProvider {
    static var previews: some View {
        LiveAudioView()
    }
}
#endif