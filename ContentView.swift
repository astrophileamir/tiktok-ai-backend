//
//  ContentView.swift
//  ai agent
//
//  Created by amirhossein taliei on 04.07.25.
//

import SwiftUI
import AVKit
import Photos

class SSESessionDelegate: NSObject, URLSessionDataDelegate {
    var onEvent: (([String: Any]) -> Void)?
    private var buffer = ""

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let text = String(data: data, encoding: .utf8) {
            buffer += text
            let events = buffer.components(separatedBy: "\n\n")
            buffer = events.last ?? ""
            for event in events.dropLast() {
                if event.hasPrefix("data:") {
                    let jsonString = event.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
                    if let jsonData = jsonString.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        DispatchQueue.main.async {
                            self.onEvent?(dict)
                        }
                    }
                }
            }
        }
    }
}

class TikTokAICreatorViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var videoURL: URL? = nil
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSaveSuccess = false
    @Published var scriptText: String? = nil
    @Published var voiceStatus: String? = nil
    @Published var imageURLs: [URL] = []
    @Published var videoStatus: String? = nil
    @Published var backendIP: String = "127.0.0.1:9000" // Default to local backend
    @Published var debugLog: [String] = []

    var backendProgressURL: String { "http://\(backendIP)/generate-video-progress" }
    var backendImageBaseURL: String { "http://\(backendIP)/images/" }
    var backendVideoURL: String { "http://\(backendIP)/generate-video" }

    private var sseDelegate: SSESessionDelegate?
    private var sseSession: URLSession?
    private var sseTask: URLSessionDataTask?

    func setBackendIP(_ ip: String) {
        backendIP = ip
        UserDefaults.standard.set(ip, forKey: "backendIP")
    }

    func generateVideo() {
        isLoading = true
        errorMessage = ""
        showError = false
        videoURL = nil
        scriptText = nil
        voiceStatus = nil
        imageURLs = []
        videoStatus = nil
        debugLog = [] // Clear previous logs
        print("[TikTokAICreator] Generate Video button tapped. Starting process...")
        guard let url = URL(string: backendProgressURL) else {
            self.errorMessage = "Invalid backend URL."
            self.showError = true
            self.isLoading = false
            print("[TikTokAICreator] Invalid backend URL: \(backendProgressURL)")
            return
        }
        let request = URLRequest(url: url)
        let delegate = SSESessionDelegate()
        delegate.onEvent = { [weak self] dict in
            print("[TikTokAICreator] Received backend event: \(dict)")
            self?.handleProgress(dict)
        }
        self.sseDelegate = delegate
        self.sseSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        self.sseTask = self.sseSession?.dataTask(with: request)
        self.sseTask?.resume()
    }

    private func handleProgress(_ dict: [String: Any]) {
        let section = dict["section"] as? String ?? ""
        let status = dict["status"] as? String ?? ""
        print("[TikTokAICreator] handleProgress called. Section: \(section), Status: \(status), Data: \(dict)")
        DispatchQueue.main.async {
            self.debugLog.append("Section: \(section), Status: \(status), Data: \(dict)")
        }
        switch section {
        case "script":
            if let script = dict["script"] as? String {
                scriptText = script
                voiceStatus = "Waiting..."
                videoStatus = "Waiting..."
            }
        case "voice":
            voiceStatus = status.isEmpty ? "Generating..." : status
        case "images":
            if let imageURL = dict["image_url"] as? String {
                let fullURL = URL(string: backendImageBaseURL + (imageURL as String).split(separator: "/").last!)!
                imageURLs.append(fullURL)
            }
        case "video":
            videoStatus = status.isEmpty ? "Generating..." : status
        case "done":
            videoStatus = "Done"
            if let videoPath = dict["video_path"] as? String {
                fetchVideo(videoPath: videoPath)
            }
            isLoading = false
        case "error":
            errorMessage = status
            showError = true
            isLoading = false
        default:
            break
        }
    }

    private func fetchVideo(videoPath: String) {
        guard let url = URL(string: backendVideoURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 600
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    self.showError = true
                }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    self.errorMessage = "Server error."
                    self.showError = true
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No video data received."
                    self.showError = true
                }
                return
            }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tiktok_ai_video.mp4")
            do {
                try data.write(to: tempURL)
                DispatchQueue.main.async {
                    self.videoURL = tempURL
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to save video: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }.resume()
    }

    func saveToPhotos() {
        guard let videoURL = videoURL else { return }
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                UISaveVideoAtPathToSavedPhotosAlbum(videoURL.path, nil, nil, nil)
                DispatchQueue.main.async {
                    self.showSaveSuccess = true
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Photos access denied."
                    self.showError = true
                }
            }
        }
    }
}

struct ProgressSection: Identifiable {
    let id = UUID()
    let title: String
    var status: String
    var details: String?
    var images: [URL] = []
}

struct ContentView: View {
    @StateObject private var viewModel = TikTokAICreatorViewModel()
    @State private var showSettings = false
    @State private var tempBackendIP = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("TikTok AI Creator")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 40)

                    if let videoURL = viewModel.videoURL {
                        VideoPlayer(player: AVPlayer(url: videoURL))
                            .frame(height: 400)
                            .cornerRadius(16)
                            .padding()
                        Button(action: viewModel.saveToPhotos) {
                            Label("Save to Photos", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if viewModel.isLoading {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionView(title: "Script", status: viewModel.scriptText == nil ? "Generating..." : "Done", details: viewModel.scriptText)
                            SectionView(title: "Voice", status: viewModel.voiceStatus ?? "Waiting...", details: nil)
                            SectionView(title: "Images", status: viewModel.imageURLs.isEmpty ? "Generating..." : "Images generated: \(viewModel.imageURLs.count)", details: nil, images: viewModel.imageURLs)
                            SectionView(title: "Video", status: viewModel.videoStatus ?? "Waiting...", details: nil)
                        }
                        .padding(.horizontal)
                        ProgressView("Generating video...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    } else if viewModel.videoURL == nil {
                        Button(action: viewModel.generateVideo) {
                            Label("Generate New Video", systemImage: "sparkles.tv")
                                .font(.title2)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    // Debug log area
                    if !viewModel.debugLog.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Debug Log (backend messages):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(viewModel.debugLog.suffix(10), id: \.self) { log in
                                        Text(log)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .frame(maxHeight: 120)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    Spacer()
                }
            }
            .navigationBarItems(trailing: Button(action: {
                tempBackendIP = viewModel.backendIP
                showSettings = true
            }) {
                Image(systemName: "gearshape")
            })
            .sheet(isPresented: $showSettings) {
                NavigationView {
                    Form {
                        Section(header: Text("Backend IP Address")) {
                            TextField("IP Address", text: $tempBackendIP)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }
                    .navigationBarTitle("Settings", displayMode: .inline)
                    .navigationBarItems(leading: Button("Cancel") {
                        showSettings = false
                    }, trailing: Button("Save") {
                        viewModel.setBackendIP(tempBackendIP)
                        showSettings = false
                    })
                }
            }
            .alert(isPresented: $viewModel.showError) {
                Alert(title: Text("Error"), message: Text(viewModel.errorMessage), dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $viewModel.showSaveSuccess) {
                Alert(title: Text("Saved!"), message: Text("Video saved to Photos."), dismissButton: .default(Text("OK")))
            }
        }
    }
}

struct SectionView: View {
    let title: String
    let status: String
    let details: String?
    var images: [URL] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(status)
                .font(.subheadline)
            if let details = details {
                Text(details)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images, id: \.self) { url in
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 80, height: 140)
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    ContentView()
}
