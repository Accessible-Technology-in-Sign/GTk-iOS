//
//  MainView.swift
//  SLRGTk
//
//  Created by Ananay Gupta on 12/31/24.
//

import SwiftUI
import Combine

class MainViewModel: ObservableObject {
    @Published var image: UIImage = UIImage()
    private var engine: CameraTestEngine

    init() {
        engine = CameraTestEngine()
        engine.camera.addCallback(name:"ImageUpdater", callback: { [weak self] newImage in
            DispatchQueue.main.async {
                self?.image = newImage
            }
        })
    }
}

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let cgImage = viewModel.image.cgImage {
                    CanvasView(cgImage: cgImage)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    Text("No image available")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .foregroundColor(.white)
                }
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
}

struct CanvasView: UIViewRepresentable {
    let cgImage: CGImage

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        let imageView = UIImageView(frame: view.bounds)
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(cgImage: cgImage)
        imageView.clipsToBounds = true
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let imageView = uiView.subviews.first as? UIImageView {
            imageView.image = UIImage(cgImage: cgImage)
        }
    }
}

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
