import SwiftUI
import ReplayKit

/// Wraps the system broadcast picker. This is the only supported way to
/// start a system-wide screen broadcast on modern iOS.
struct BroadcastButton: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let picker = RPSystemBroadcastPickerView(
            frame: CGRect(x: 0, y: 0, width: 60, height: 60)
        )
        // Bundle ID of the broadcast extension target
        picker.preferredExtension = "com.yourname.sight.SightBroadcast"
        picker.showsMicrophoneButton = false

        // Restyle the internal button so it fits the UI
        for sub in picker.subviews {
            if let button = sub as? UIButton {
                button.imageView?.tintColor = .clear
                button.setImage(nil, for: .normal)
                button.backgroundColor = .clear
            }
        }

        let container = UIView()
        container.addSubview(picker)
        picker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            picker.topAnchor.constraint(equalTo: container.topAnchor),
            picker.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ContentView: View {
    @StateObject private var session = SessionController()
    @State private var showKey = false

    private let green = Color(red: 0.11, green: 0.72, blue: 0.45)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    header

                    if !session.running {
                        setupSection
                    } else {
                        liveSection
                    }

                    if !session.errorText.isEmpty {
                        Text(session.errorText)
                            .font(.footnote)
                            .foregroundColor(.red.opacity(0.9))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(10)
                    }

                    if !session.log.isEmpty {
                        logSection
                    }
                }
                .padding(18)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Circle()
                .fill(session.broadcasting ? Color.red : Color.gray)
                .frame(width: 9, height: 9)
            Text("Sight")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Text(session.broadcasting ? "LIVE" : "Not live")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(session.broadcasting ? .red : .gray)
                .padding(.horizontal, 11).padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
        }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 16) {

            VStack(alignment: .leading, spacing: 7) {
                Text("Answers without asking")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)
                Text("Start a screen broadcast and Sight reads whatever question is on your screen, solves it, and says the answer aloud. Works in any app. You never tap a thing.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineSpacing(3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(green.opacity(0.12))
            .cornerRadius(14)

            VStack(alignment: .leading, spacing: 8) {
                Text("ANTHROPIC API KEY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                Group {
                    if showKey {
                        TextField("sk-ant-…", text: $session.apiKey)
                    } else {
                        SecureField("sk-ant-…", text: $session.apiKey)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color.white.opacity(0.06))
                .cornerRadius(11)
                .foregroundColor(.white)

                Button(showKey ? "Hide key" : "Show key") { showKey.toggle() }
                    .font(.footnote)
                    .foregroundColor(green)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("SCAN EVERY \(Int(session.interval))s")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                Slider(value: $session.interval, in: 4...20, step: 1)
                    .tint(green)
                Text("How often Sight reads the screen. Slower costs less.")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Button {
                session.start()
            } label: {
                Text("Start session")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(green)
                    .foregroundColor(.black)
                    .cornerRadius(14)
            }
        }
    }

    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 16) {

            VStack(alignment: .leading, spacing: 10) {
                Text("STEP 1 — START BROADCASTING")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                Text("Tap below, choose Sight, then Start Broadcast. Leave the app and open your question — Sight keeps listening.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .lineSpacing(2)

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(green.opacity(0.15))
                        .frame(height: 56)
                    Text(session.broadcasting ? "Broadcasting" : "Tap to start broadcast")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(green)
                    BroadcastButton()
                        .frame(height: 56)
                        .opacity(0.02)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .cornerRadius(14)

            HStack(spacing: 8) {
                Circle()
                    .fill(session.speaker.isSpeaking ? Color.blue : green)
                    .frame(width: 7, height: 7)
                Text(session.status)
                    .font(.footnote)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(session.scanCount) scans")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(session.currentAnswer.isEmpty ? "WAITING FOR A QUESTION" : "ANSWER")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)

                if session.currentAnswer.isEmpty {
                    Text("Open a question on your screen")
                        .font(.footnote)
                        .foregroundColor(.gray.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 14)
                } else {
                    Text("\u{201C}\(session.currentQuestion)\u{201D}")
                        .font(.system(size: 12))
                        .italic()
                        .foregroundColor(.gray)
                    Text(session.currentAnswer)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .lineSpacing(4)

                    Button {
                        session.replayLast()
                    } label: {
                        Text("Hear again")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .cornerRadius(14)

            Button {
                session.stop()
            } label: {
                Text("Stop session")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.clear)
                    .foregroundColor(.red)
                    .overlay(RoundedRectangle(cornerRadius: 13)
                        .stroke(Color.red.opacity(0.35), lineWidth: 1.5))
            }
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("PREVIOUS ANSWERS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)

            ForEach(session.log) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.time, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.6))
                    Text(entry.question)
                        .font(.system(size: 12))
                        .italic()
                        .foregroundColor(.gray)
                    Text(entry.answer)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .cornerRadius(11)
            }
        }
    }
}
