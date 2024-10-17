//
//  ContentView.swift
//  FunVoiceChanger
//
//  Created by Dev Reptech on 10/02/2024.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject var recorder = AudioRecorder()
    @State private var selectedVoiceIndex = 0
    @State private var isDarkMode = false

    let voiceEffects = ["Original", "Women", "Older Women", "Younger Women", "Teenage Girl", "Man", "Older Man", "Young Man", "Kid"]

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    isDarkMode.toggle()
                    toggleAppearance()
                }) {
                    Image(systemName: isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                        .foregroundColor(.blue)
                }
                .padding()
            }

            Text("Your Fun Voice Changer")
                .font(.title)
                .bold()
                .padding(.top, 20)
                .padding(.leading, 20)
                .multilineTextAlignment(.center)

            Text("Please select multiple voices from the dropdown menu below")
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.leading, 20)
                .padding(.top, 20)
                .multilineTextAlignment(.center)

            Section {
                Picker(selection: $selectedVoiceIndex, label: Text("Select Voice")) {
                    ForEach(0..<voiceEffects.count, id: \.self) { index in
                        Text(voiceEffects[index])
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .foregroundColor(.blue)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .shadow(radius: 5)
                )
            }

            Spacer()

            HStack {
                RoundedButton(action: {
                self.recorder.startRecording()
                print("record button hit")
                }, label: "Record")

                RoundedButton(action: {
                self.recorder.stopRecording()
                print("stop button hit")
                }, label: "Stop")

                RoundedButton(action: {
                self.recorder.playLastRecording(voiceEffect: self.selectedVoiceIndex)
                }, label: "Play Last Recording")
            }
            .padding()

            Spacer()

            List {
                ForEach(recorder.recordedLists) { list in
                    VStack(alignment: .leading) {
                        Text("Recording \(list.id)")
                            .font(.headline)
                        ForEach(list.recordings) { recording in
                            Button(action: {
                                self.recorder.playRecording(voiceEffect: self.selectedVoiceIndex, file: recording.file)
                            }) {
                                Text("\(recording.file.lastPathComponent) - Duration: \(recording.duration)s")
                            }
                        }
                    }
                }
            }

            Spacer()

            Button(action: {
                self.shareRecording()
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.blue)
            .clipShape(Circle())
            .shadow(radius: 5)
        }
        .padding()
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    func toggleAppearance() {
        UIApplication.shared.windows.first?.rootViewController?.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
    }

    func shareRecording() {
        guard let lastRecording = recorder.recordedLists.last?.recordings.last else {
            print("No recorded files available to share")
            return
        }

        let activityViewController = UIActivityViewController(activityItems: [lastRecording.file], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(activityViewController, animated: true, completion: nil)
    }
}

struct RoundedButton: View {
    let action: () -> Void
    let label: String

    var body: some View {
        Button(action: action) {
            Text(label)
                .padding()
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10)
                .shadow(radius: 5)
        }
    }
}

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder?
    var audioPlayerNode: AVAudioPlayerNode?
    var audioEngine: AVAudioEngine?
    var pitchEffect: AVAudioUnitTimePitch?

    @Published var recordedLists: [RecordedFileList] = []
    var currentRecordingList: RecordedFileList?
    var currentRecordingStartTime: Date?

    override init() {
        super.init()

        audioEngine = AVAudioEngine()
        pitchEffect = AVAudioUnitTimePitch()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            session.requestRecordPermission() { allowed in
                DispatchQueue.main.async {
                    if allowed {
                        print("Permission granted")
                    } else {
                        print("Permission denied")
                    }
                }
            }
        } catch {
            print("Failed to set up recording session")
        }
    }

    func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording\(recordedLists.count + 1).m4a")

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            // Start the recording start time timer
            currentRecordingStartTime = Date()
        } catch {
            print("Error recording audio: \(error.localizedDescription)")
        }
    }


    func stopRecording() {
        audioRecorder?.stop()

        // Save the recorded file
        if let url = audioRecorder?.url, let startTime = currentRecordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            let recording = RecordedFile(id: recordedLists.count + 1, file: url, duration: Int(duration))
            if var list = currentRecordingList {
                list.recordings.append(recording)
            } else {
                let newList = RecordedFileList(id: recordedLists.count + 1, recordings: [recording])
                recordedLists.append(newList)
            }
            currentRecordingList = nil
            currentRecordingStartTime = nil
        }
    }

    func playRecording(voiceEffect: Int, file: URL) {
        do {
            audioEngine = AVAudioEngine()
            audioPlayerNode = AVAudioPlayerNode()
            audioEngine?.attach(audioPlayerNode!)
            audioEngine?.attach(pitchEffect!)

            let audioFile = try AVAudioFile(forReading: file)
            let audioFormat = audioFile.processingFormat
            audioEngine?.connect(audioPlayerNode!, to: pitchEffect!, format: audioFormat)
            audioEngine?.connect(pitchEffect!, to: audioEngine!.outputNode, format: audioFormat)
            pitchEffect?.pitch = voiceEffect == 0 ? 1.0 : Float(voiceEffect) * 100.0

            audioPlayerNode?.scheduleFile(audioFile, at: nil, completionHandler: nil)
            try audioEngine?.start()
            audioPlayerNode?.play()
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }

    func playLastRecording(voiceEffect: Int) {
        guard let lastRecording = recordedLists.last?.recordings.last else {
            print("No recorded files available")
            return
        }
        playRecording(voiceEffect: voiceEffect, file: lastRecording.file)
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}

struct RecordedFile: Identifiable {
    var id: Int
    var file: URL
    var duration: Int
}

struct RecordedFileList: Identifiable {
    var id: Int
    var recordings: [RecordedFile]
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
