
import SwiftUI
import QuickPoseCore
import QuickPoseCamera
import QuickPoseSwiftUI

struct ValueBar: View {
    var value: Double
    var opacity: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(Color.white)
                    .frame(width: geometry.size.width * CGFloat(value))
                    .opacity(opacity)
            }.cornerRadius(8)
        }.frame(height: 16)
    }
}

extension UIImage {
  func mergeWith(topImage: UIImage) -> UIImage {
    let bottomImage = self

    UIGraphicsBeginImageContext(size)


    let areaSize = CGRect(x: 0, y: 0, width: bottomImage.size.width, height: bottomImage.size.height)
    bottomImage.draw(in: areaSize)

    topImage.draw(in: areaSize, blendMode: .normal, alpha: 1.0)

    let mergedImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return mergedImage
  }
}

struct QuickPoseStatsView: View {
    @Environment(\.geometry) private var geometrySize
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    
    let quickPose: QuickPose
    let showLag = false
    @Binding var lastFPS: Int
    @Binding var lastLag: Double
    
    var body: some View {
        Text("Powered by QuickPose.ai v\(quickPose.quickPoseVersion())\n\(lastFPS) fps" + (showLag ? "lag \(String(format: "%.2f", lastLag))ms" : "")) // remove logo here, but attribution appreciated
            .font(.system(size: 16, weight: .semibold).monospaced()).foregroundColor(.white)
            .frame(height: 40 + safeAreaInsets.bottom, alignment: .center)
            .padding(.bottom, 0)
    }
}


struct QuickPosePickerView: View {
    @Environment(\.geometry) private var geometrySize
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @Environment(\.dismiss) private var dismiss
    private let initialBrightness = UIScreen.main.brightness
    let title: String
    static let fastLabel = "Fast (Body Points only)"
    @State private var showDebugString: String = "Off"
    @State private var performance: String = UserDefaults.standard.bool(forKey: "performanceFast") ? QuickPosePickerView.fastLabel : "Normal"
    @State private var targetFPS: Double? = UserDefaults.standard.bool(forKey: "performanceFast") ? 60 : nil
    
    @State private var lastDebugResult: QuickPoseCore.QuickPose.FeatureResult? = nil
    
    @State private var selectedFeatures: [QuickPose.Feature] = [.overlay(.wholeBody)]
    @State private var selectedComponent: String = QuickPose.Feature.allDemoFeatureComponents().first!
    @State var counter = QuickPoseThresholdCounter()
    @State var timer = QuickPoseThresholdTimer()
    
    // @State so the SDK instance survives view-struct recreation (e.g. NavigationStack
    // re-evaluating the destination): otherwise onDisappear captures a fresh, never-started
    // QuickPose, stop() becomes a no-op, and each visit leaks a running MediaPipe graph.
    @State private var quickPose = QuickPose(sdkKey: QuickPoseConfig.sdkKey) // register for your free key at https://dev.quickpose.ai
    @State private var overlayImage: UIImage?
    
    @State var useFrontCamera: Bool = true
    
    @State private var lastResult: String? = nil
    @State private var lastResultImage: UIImage? = nil
    @State private var lastFPS: Int = 0
    @State private var lastLag: Double = 0
    @State private var showResult: String? = nil
    @State private var cameraViewOpacity: Double = 0
    @State private var captureButtonOpacity: Double = 0
    @State private var counterVisibility: Double = 0
    @State private var timerVisibility: Double = 0
    @State private var customUserHeight: Double = 100
    @State private var count: Int = 0
    @State private var measure: Double = 0
    @State private var timeInPosition: String = ""
    @State private var heightInCMText: String = ""
    @State private var feedbackText: String? = nil
    @State private var showHeightAlert: Bool = false
    @State private var resultsImage: UIImage? = nil

    init(features: [QuickPose.Feature] = [.overlay(.wholeBody)], title: String = "Demo") {
        self.title = title
        self._selectedFeatures = State(initialValue: features)
    }

    var body: some View {
        ZStack(alignment: .top) {
            if ProcessInfo.processInfo.isiOSAppOnMac, let url = Bundle.main.url(forResource: "rain-dance", withExtension: "mov") {
                QuickPoseSimulatedCameraView(useFrontCamera: false, delegate: quickPose, video: url)
            } else {
                QuickPoseCameraSwitchView(useFrontCamera: $useFrontCamera, delegate: quickPose, frameRate: $targetFPS)
            }
            QuickPoseOverlayView(overlayImage: $overlayImage)
        }
        .overlay(alignment: .top) {
            HStack(spacing: 8) {
                Button(action: {
                    dismiss()
                }) {
                    Text(Image(systemName: "chevron.left"))
                        .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                        .padding(8)
                        .background(Circle().foregroundColor(Color("AccentColor").opacity(0.8)))
                }

                Text(title)
                    .font(.system(size: 20, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 44/2).foregroundColor(Color("AccentColor").opacity(0.8)))

                Spacer()

                Menu {
                    Picker("Performance", selection: $performance) {
                        ForEach([QuickPosePickerView.fastLabel, "Normal"], id: \.self) { feature in
                            Text(feature)
                        }
                    }
                    .onChange(of: performance) { _ in
                        // changing model complexity requires restart of quickpose, but tracking can be changed per frame
                        quickPose.update(features: selectedFeatures, modelConfig: performance == "Normal" ? QuickPose.ModelConfig() : QuickPose.ModelConfig(detailedFaceTracking: false, detailedHandTracking: false))
                        UserDefaults.standard.set(performance == QuickPosePickerView.fastLabel , forKey: "performanceFast")
                        targetFPS = performance == QuickPosePickerView.fastLabel ? 60 : nil
                    }
                    Picker("Debug", selection: $showDebugString) {
                        ForEach(["On","Off"], id: \.self) { feature in
                            Text("Debug \(feature)")
                        }
                    }
                } label: {
                    Text(Image(systemName: "ellipsis"))
                        .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                        .padding(8)
                        .background(Circle().foregroundColor(Color("AccentColor").opacity(0.8)))
                }

                Button(action: {
                    shareScreenshot()
                }) {
                    Text(Image(systemName: "square.and.arrow.up"))
                        .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                        .padding(8)
                        .background(Circle().foregroundColor(Color("AccentColor").opacity(0.8)))
                }.frame(alignment: .trailing)

                Button(action: {
                    useFrontCamera.toggle()
                }) {
                    Text(Image(systemName: "arrow.triangle.2.circlepath.camera"))
                        .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                        .padding(8)
                        .background(Circle().foregroundColor(Color("AccentColor").opacity(0.8)))
                }.frame(alignment: .trailing)
                
                
            }
            .padding(.top, 24 + safeAreaInsets.top)
            .padding(.horizontal, 16)
            .frame(width: geometrySize.width)
        }
        .alert("Add Height", isPresented: $showHeightAlert)
        {
            TextField("Your height in CM, e.g. 150", text: $heightInCMText).keyboardType(.numberPad)
            Button("OK"){
                selectedFeatures = [.measureLineBody(p1: .shoulder(side: .left), p2: .shoulder(side: .right), userHeight: Double(heightInCMText) ?? 100, format: "%.fcm")]
                quickPose.update(features: selectedFeatures)
            }
        } message: {
            Text("To show a ruler in CM, please enter your height in CM. ")
        }
        .overlay(alignment: .bottom) {
            if let resultsImage =  resultsImage {
                Image(uiImage: resultsImage).resizable().aspectRatio(contentMode:  .fill)
                    .frame(width: geometrySize.width, height: geometrySize.height)
            }
        }
        .overlay(alignment: .bottom) {
            
            Button(action: {
                showResult = lastResult
                resultsImage = lastResultImage!.mergeWith(topImage: overlayImage!)
            }) {
                Text("Capture")
                    .font(.system(size: 24, weight: .semibold)).foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal,16)
                    .frame(width: geometrySize.width - 24*2)
                    .background(RoundedRectangle(cornerRadius: 44).foregroundColor(Color("AccentColor")))
                    .padding(.bottom, 40 + safeAreaInsets.bottom)
            }
            .alert(item: $showResult) { result in
                Alert(title: Text("Result"),
                      message: Text("Your measurement was \(result)"),
                      dismissButton: .default(Text("OK"))
                )
            }.opacity(captureButtonOpacity)
        }
        .overlay(alignment: .bottom) {
            QuickPoseStatsView(quickPose: quickPose, lastFPS: $lastFPS, lastLag: $lastLag)
        }
        .overlay(alignment: .bottom) {
            if selectedFeatures.first != nil {
                VStack(spacing: 0) {
                    Text("\(count)")
                        .font(.system(size: 72, weight: .bold).monospacedDigit()).foregroundColor(.white)
                    Text(isFitnessFeature ? "REPS" : (selectedFeatures.first?.displayString ?? ""))
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(.white.opacity(0.9))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 24)
                .background(RoundedRectangle(cornerRadius: 16).foregroundColor(Color("AccentColor").opacity(0.6)))
                .padding(.bottom, 40 + safeAreaInsets.bottom).opacity(counterVisibility)
                ValueBar(value: measure, opacity:counterVisibility)
            }
        }
        .overlay(alignment: .center) {
            if let feedbackText = feedbackText {
                Text(feedbackText)
                    .font(.system(size: 26, weight: .semibold)).foregroundColor(.white).multilineTextAlignment(.center)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 8).foregroundColor(Color("AccentColor").opacity(0.8)))
                    .padding(.bottom, 40 + safeAreaInsets.bottom)
                    
            }
        }
        .overlay(alignment: .bottom) {
            if let feature = selectedFeatures.first {
                Text("\(feature.displayString): " + timeInPosition)
                    .font(.system(size: 32, weight: .semibold)).foregroundColor(.white)
                    .padding(.bottom, 40 + safeAreaInsets.bottom).opacity(timerVisibility)
                ValueBar(value: measure, opacity: timerVisibility)
            }
        }
        .overlay(alignment: .bottom) { // showDebug
            if let result = self.lastDebugResult, showDebugString == "On" {
                Text("\(result.stringValue) \(String(format: "%.2f", result.value))")
                    .font(.system(size: 32, weight: .semibold)).foregroundColor(.white)
                    .padding(.bottom, 40*2 + safeAreaInsets.bottom)
            }
        }
        
        .onAppear {
            if case let .measureLineBody(_, _, customHeight, _, _) = selectedFeatures.first, customHeight != nil {
                showHeightAlert = true
            }
            let featuresWithBg = selectedFeatures + [.overlayHasCameraAsBackground(darkenCamera: 0)]
            quickPose.start(features: featuresWithBg, modelConfig: performance == "Normal" ? QuickPose.ModelConfig() : QuickPose.ModelConfig(detailedFaceTracking: false, detailedHandTracking: false), onStart: {
                withAnimation { cameraViewOpacity = 1.0 } // unhide the camera when loaded
            }, onFrame: { status, image, features, feedback, landmarks in
                overlayImage = image
                if case let .success(performance) = status {
                    lastFPS = performance.fps
                    lastLag = performance.latency*1000
                    self.lastDebugResult = nil

                    if let landmarks {
                        print(landmarks.allLandmarksForBody()[0])
                    }
                    
                    if case .rangeOfMotion = selectedFeatures.first, let result = features[selectedFeatures.first!] {
                        lastResult = result.stringValue
//                        lastResultImage = cameraImage
                        if captureButtonOpacity == 0 { // only show button when reading available
                            withAnimation { captureButtonOpacity = 1 }
                        }
                    } else if captureButtonOpacity == 1 {
                        withAnimation { captureButtonOpacity = 0 }
                    }
                    if let feedback = feedback[selectedFeatures.first!]  {
                        feedbackText = feedback.displayString
                    } else {
                        feedbackText = nil
                    }
                    if case .fitness = selectedFeatures.first, let result = features[selectedFeatures.first!]  {
                        measure = result.value
                        if (result.stringValue.lowercased().contains("plank")) {
                            // timed exercises have no rep counter
                            _ = timer.time(result.value)
                            timeInPosition = String(format: "%.2f", timer.state.time)
                            timerVisibility = 1
                        } else {
                            _ = counter.count(result.value)
                            count = counter.state.count
                            counterVisibility = 1
                        }
                    } else if case .raisedFingers = selectedFeatures.first, let result = features[selectedFeatures.first!] {
                        count = Int(result.value)
                        counterVisibility = 1
                    } else if case .thumbsUp = selectedFeatures.first, let result = features[selectedFeatures.first!] {
                        count = Int(result.value > 0.7 ? 1 : 0)
                        counterVisibility = 1
                    } else if case .thumbsUpOrDown = selectedFeatures.first, let result = features[selectedFeatures.first!] {
                        count = Int(result.stringValue.lowercased().contains("up") && result.value > 0.7 ? 1 : result.stringValue.lowercased().contains("down") && result.value > 0.7 ? -1 : 0)
                        counterVisibility = 1
                    } else {
                        counterVisibility = 0
                    }

                    
                }
            })
            
            UIApplication.shared.isIdleTimerDisabled = true  // keep screen on when in use
            
        }
        .onDisappear {
            timer.stop()
            quickPose.stop()
            UIApplication.shared.isIdleTimerDisabled = false
            UIScreen.main.brightness = self.initialBrightness
        }
        .frame(width: geometrySize.width + safeAreaInsets.leading + safeAreaInsets.trailing)
        .edgesIgnoringSafeArea(.all)
        .opacity(cameraViewOpacity)
        .background(Color.black)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)

    }

    private var isFitnessFeature: Bool {
        if case .fitness = selectedFeatures.first {
            return true
        }
        return false
    }

    private func shareScreenshot() {
        guard let image = overlayImage, let data = image.jpegData(compressionQuality: 0.95) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("quickpose_screenshot.jpg")
        try? data.write(to: url)
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let root = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        if let pop = vc.popoverPresentationController {
            pop.sourceView = presenter.view
            pop.sourceRect = CGRect(x: presenter.view.bounds.midX, y: 64, width: 0, height: 0)
            pop.permittedArrowDirections = .up
        }
        presenter.present(vc, animated: true)
    }
}

/// Image fills for the overlay style presets: a bundled photo (NASA Hubble Ultra
/// Deep Field, public domain) and one procedural orange radial gradient.
enum StyleTextures {
    private static var cache: [String: UIImage] = [:]

    static func image(named name: String) -> UIImage? {
        if let cached = cache[name] { return cached }
        let image: UIImage?
        switch name {
        case "Galaxy": image = UIImage(named: "galaxy")
        case "Orange Glow": image = orangeRadialGradient()
        default: image = nil
        }
        cache[name] = image
        return image
    }

    private static func orangeRadialGradient() -> UIImage {
        let size = CGSize(width: 360, height: 640)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let colors = [UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1).cgColor,
                          UIColor(red: 1, green: 0.45, blue: 0, alpha: 1).cgColor,
                          UIColor(red: 0.55, green: 0.05, blue: 0, alpha: 1).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1])!
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            context.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                                 endCenter: center, endRadius: size.height * 0.7, options: [])
        }
    }
}

extension String: Identifiable {
    public typealias ID = Int
    public var id: Int {
        return hash
    }
}

extension QuickPose.Feature {
    public static func allDemoFeatures(component: String) -> [[QuickPose.Feature]] {
        if component == "Measurement" {
            return [
                [.measureLineBody(p1: .shoulder(side: .left), p2: .shoulder(side: .right), userHeight: nil, format: nil)],
                [.measureLineBody(p1: .shoulder(side: .left), p2: .shoulder(side: .right), userHeight: 100, format: "%.fcm")],
                ]
        } else if component == "Health" {
            return [[.rangeOfMotion(.shoulder(side: .left, clockwiseDirection: false))], [.rangeOfMotion(.shoulder(side: .right, clockwiseDirection: true))],
                    [.rangeOfMotion(.hip(side: .right, clockwiseDirection: true))], [.rangeOfMotion(.knee(side: .right, clockwiseDirection: true))], [.rangeOfMotion(.neck(clockwiseDirection: false))], [.rangeOfMotion(.back(clockwiseDirection: false))]]
        } else if component == "Input" {
            return [[QuickPose.Feature.raisedFingers()], [QuickPose.Feature.thumbsUp()], [QuickPose.Feature.thumbsUpOrDown()]]
        } else if component == "Conditional" {
            let greenStyle = QuickPose.Style(conditionalColors: [QuickPose.Style.ConditionalColor(min: 40, max: nil, color: UIColor.green)])
            let redStyle = QuickPose.Style(conditionalColors: [QuickPose.Style.ConditionalColor(min: 180, max: nil, color: UIColor.red)])
            return [[.rangeOfMotion(.shoulder(side: .left, clockwiseDirection: false), style: greenStyle)], [.rangeOfMotion(.knee(side: .right, clockwiseDirection: true), style: redStyle)]]
        } else if component == "Fitness" {
            return fitnessSections().flatMap { $0.features }
        } else if component == "Sports" {
            let bikeStyle = QuickPose.Style(relativeFontSize: 0.33, relativeArcSize: 0.4, relativeLineWidth: 0.3)
            let feature1: QuickPose.Feature = .rangeOfMotion(.shoulder(side: .right, clockwiseDirection: false), style: bikeStyle)
            let feature2: QuickPose.Feature = .rangeOfMotion(.elbow(side: .right, clockwiseDirection: false), style: bikeStyle)
            let feature3: QuickPose.Feature = .rangeOfMotion(.hip(side: .right, clockwiseDirection: false), style: bikeStyle)
            let feature4: QuickPose.Feature = .rangeOfMotion(.knee(side: .right, clockwiseDirection: true), style: bikeStyle)
            return [[feature1,  feature2, feature3, feature4]]
        } else {
            return QuickPose.Landmarks.Group.commonLimbs().map { [QuickPose.Feature.overlay($0)] } + [[QuickPose.Feature.showPoints()]]
        }
    }
    
    public static func fitnessSections() -> [(name: String, features: [[QuickPose.Feature]])] {
        return [
            (name: "Legs & Glutes", features: [
                [.fitness(.squats)],
                [.fitness(.sumoSquats)],
                [.fitness(.lunges(side:.left))],
                [.fitness(.lunges(side:.right))],
                [.fitness(.sideLunges(side:.left))],
                [.fitness(.sideLunges(side:.right))],
                [.fitness(.gluteBridge)],
                [.fitness(.hipAbductionStanding(side:.left))],
                [.fitness(.hipAbductionStanding(side:.right))],
            ]),
            (name: "Core", features: [
                [.fitness(.sitUps)],
                [.fitness(.vUps)],
                [.fitness(.legRaises)],
                [.fitness(.cobraWings)],
                [.fitness(.plank)],
                [.fitness(.plankStraightArm)],
            ]),
            (name: "Upper Body", features: [
                [.fitness(.pushUps)],
                [.fitness(.frontPushUps)],
                [.fitness(.bicepCurls)],
                [.fitness(.bicepCurlsSingleArm(side:.left))],
                [.fitness(.bicepCurlsSingleArm(side:.right))],
                [.fitness(.overheadDumbbellPress)],
                [.fitness(.lateralRaises)],
                [.fitness(.frontRaises)],
                [.fitness(.overarmReachBilateral)],
            ]),
            (name: "Cardio", features: [
                [.fitness(.jumpingJacks)],
                [.fitness(.kneeRaisesBilateral)],
                [.fitness(.highKneeTaps)],
                [.fitness(.shoulderTaps)],
                [.fitness(.mountainClimbers)],
                [.fitness(.boxing)],
                [.fitness(.burpees)],
            ]),
        ]
    }

    public static func overlayStylePresets() -> [(title: String, features: [QuickPose.Feature])] {
        let presets: [(String, QuickPose.Style)] = [
            ("Classic White", QuickPose.Style()),
            ("Green", QuickPose.Style(color: .green)),
            ("Red", QuickPose.Style(color: .red)),
            ("Thick Lines", QuickPose.Style(relativeLineWidth: 2.0)),
            ("Dashed", QuickPose.Style(linePattern: .dashed)),
            ("Dotted", QuickPose.Style(linePattern: .dotted)),
            ("Glow", QuickPose.Style(color: .green, shadow: QuickPose.Style.Shadow(color: .green, radius: 32, offsetX: 0, offsetY: 0))),
            ("Shadow", QuickPose.Style(shadow: QuickPose.Style.Shadow(color: .black, radius: 14, offsetX: 0, offsetY: 10))),
            ("Outlined", QuickPose.Style(outline: QuickPose.Style.Outline(color: .black, relativeWidth: 0.6))),
            ("Orange Glow Fill", QuickPose.Style(relativeLineWidth: 2.0, imageFill: StyleTextures.image(named: "Orange Glow"))),
            ("Galaxy Fill", QuickPose.Style(relativeLineWidth: 2.0, imageFill: StyleTextures.image(named: "Galaxy"))),
        ]
        return presets.map { (title: $0.0, features: [.overlay(.wholeBody, style: $0.1)]) }
    }

    public static func allDemoFeatureComponents() -> [String] {
        return ["General", "Input", "Fitness", "Health", "Conditional", "Sports", "Measurement"]
    }
}
