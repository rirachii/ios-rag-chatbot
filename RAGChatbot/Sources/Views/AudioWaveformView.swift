import SwiftUI

struct WaveformBar: Shape {
    var value: CGFloat
    
    var animatableData: CGFloat {
        get { value }
        set { value = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let barWidth = rect.width
        let barHeight = rect.height * value
        
        let roundedRect = CGRect(
            x: 0,
            y: rect.height - barHeight,
            width: barWidth,
            height: barHeight
        )
        
        path.addRoundedRect(
            in: roundedRect,
            cornerSize: CGSize(width: barWidth/2, height: barWidth/2)
        )
        
        return path
    }
}

struct AudioWaveformView: View {
    @Binding var soundLevel: Float
    let numberOfBars = 30
    let spacing: CGFloat = 4
    let minBarHeight: CGFloat = 3
    
    @State private var levels: [CGFloat] = []
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    // Previous sound level for threshold detection
    @State private var previousSoundLevel: Float = 0
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<numberOfBars, id: \.self) { index in
                WaveformBar(value: levels.count > index ? levels[index] : minBarHeight)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.5),
                                Color.blue
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3)
                    .animation(.easeInOut(duration: 0.2), value: levels)
            }
        }
        .frame(height: 50)
        .onAppear {
            levels = Array(repeating: minBarHeight, count: numberOfBars)
        }
        .onReceive(timer) { _ in
            updateLevels()
        }
        .onChange(of: soundLevel) { newLevel in
            // Trigger haptic feedback for significant level changes
            if abs(newLevel - previousSoundLevel) > 0.3 {
                HapticService.shared.audioLevelChanged(newLevel)
            }
            previousSoundLevel = newLevel
        }
    }
    
    private func updateLevels() {
        var newLevels = levels
        let currentLevel = CGFloat(min(max(soundLevel, 0), 1))
        
        for i in (1..<numberOfBars).reversed() {
            newLevels[i] = levels[i-1]
        }
        
        let randomVariation = CGFloat.random(in: -0.1...0.1)
        newLevels[0] = max(currentLevel + randomVariation, minBarHeight)
        
        levels = newLevels
    }
}

struct LiveAudioView: View {
    @StateObject private var audioViewModel = LiveAudioViewModel()
    @GestureState private var isPressed = false
    
    var body: some View {
        VStack {
            AudioWaveformView(soundLevel: $audioViewModel.soundLevel)
                .padding()
            
            Button(action: {
                // Button tap handling moved to gesture
            }) {
                Image(systemName: audioViewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(audioViewModel.isRecording ? .red : .blue)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
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
                        audioViewModel.toggleRecording()
                    }
            )
            .padding()
        }
    }
}

class LiveAudioViewModel: NSObject, ObservableObject, VoiceServiceDelegate {
    @Published var soundLevel: Float = 0.0
    @Published var isRecording: Bool = false
    
    private let voiceService = VoiceService.shared
    
    override init() {
        super.init()
        voiceService.delegate = self
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        voiceService.startRecording()
        isRecording = true
        HapticService.shared.recordingStarted()
    }
    
    private func stopRecording() {
        voiceService.stopRecording()
        isRecording = false
        HapticService.shared.recordingStopped()
    }
    
    // MARK: - VoiceServiceDelegate
    
    func voiceService(_ service: VoiceService, didRecognizeText text: String) {
        print("Recognized: \(text)")
    }
    
    func voiceService(_ service: VoiceService, didFailWithError error: Error) {
        print("Error: \(error.localizedDescription)")
        isRecording = false
        HapticService.shared.recordingError()
    }
    
    func voiceService(_ service: VoiceService, didUpdateSoundLevel level: Float) {
        DispatchQueue.main.async {
            self.soundLevel = level
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