//
//  QuickPose_DemoApp.swift
//  QuickPose Demo
//
//  Created by Peter Nash on 12/12/2022.
//

import SwiftUI
import AVFoundation
import QuickPoseCore

enum QuickPoseConfig {
    /// Register for your free SDK key at https://dev.quickpose.ai and paste it here.
    static let sdkKey = "YOUR-SDK-KEY-HERE"

    static var hasSDKKey: Bool {
        !sdkKey.isEmpty && sdkKey != "YOUR-SDK-KEY-HERE"
    }
}

@main
struct QuickPose_DemoApp: App {
    var body: some Scene {
        WindowGroup {
            GeometryReader { fullScreenGeometry in
                DemoAppView()
                    .environment(\.geometry, fullScreenGeometry.size)
                    .environment(\.safeAreaInsets, fullScreenGeometry.safeAreaInsets)
                    .background(Color("AccentColor"))
            }
        }
    }
}

struct DemoAppView: View {
    @State var cameraPermissionGranted = !ProcessInfo.processInfo.isiOSAppOnMac
    var body: some View {
        NavigationStack {
            if cameraPermissionGranted {
                LandingView()
            } else {
                Text("Camera access is required to run the QuickPose demos.")
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }.onAppear {
            AVCaptureDevice.requestAccess(for: .video) { accessGranted in
                DispatchQueue.main.async {
                    self.cameraPermissionGranted = accessGranted
                }
            }
        }
    }
}

struct FeatureCategory: Identifiable {
    let name: String
    let icon: String
    let subtitle: String
    var id: String { name }

    static let all: [FeatureCategory] = [
        FeatureCategory(name: "Fitness", icon: "figure.strengthtraining.traditional", subtitle: "Squats, push-ups, planks and more, with rep counting"),
        FeatureCategory(name: "Health", icon: "heart.fill", subtitle: "Range of motion for shoulder, hip, knee, neck and back"),
        FeatureCategory(name: "Sports", icon: "bicycle", subtitle: "Cycling and rowing joint angles"),
        FeatureCategory(name: "Input", icon: "hand.raised.fill", subtitle: "Raised fingers, thumbs up and thumbs down"),
        FeatureCategory(name: "Overlay Colours", icon: "paintbrush.fill", subtitle: "Styled skeleton overlays: colours, glows, outlines and image fills"),
        FeatureCategory(name: "Measurement", icon: "ruler.fill", subtitle: "Measure body distances on screen or in cm"),
        FeatureCategory(name: "Conditional", icon: "paintpalette.fill", subtitle: "Overlays that change color on thresholds"),
        FeatureCategory(name: "General", icon: "person.crop.rectangle", subtitle: "Skeleton overlays and body landmarks"),
    ]
}

struct LandingView: View {
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    @State private var showSDKKeyAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("QuickPose Demos")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)
                Text("Pick a feature to try it live with your camera")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 8)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(FeatureCategory.all) { category in
                    NavigationLink {
                        FeatureListView(category: category)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: category.icon)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(height: 36)
                            Text(category.name)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(category.subtitle)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 16).foregroundColor(.white.opacity(0.15)))
                    }
                }
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                LandingLinkRow(icon: "key.fill", title: "Create a free SDK key", subtitle: "dev.quickpose.ai", url: "https://dev.quickpose.ai")
                Divider().overlay(Color.white.opacity(0.2)).padding(.leading, 52)
                LandingLinkRow(icon: "book.fill", title: "Documentation", subtitle: "docs.quickpose.ai", url: "https://docs.quickpose.ai")
                Divider().overlay(Color.white.opacity(0.2)).padding(.leading, 52)
                LandingLinkRow(icon: "chevron.left.forwardslash.chevron.right", title: "GitHub", subtitle: "github.com/quickpose", url: "https://github.com/quickpose")
            }
            .background(RoundedRectangle(cornerRadius: 16).foregroundColor(.white.opacity(0.15)))
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color("AccentColor").ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            showSDKKeyAlert = !QuickPoseConfig.hasSDKKey
        }
        .alert("SDK Key Required", isPresented: $showSDKKeyAlert) {
            Button("Get a free SDK key") {
                UIApplication.shared.open(URL(string: "https://dev.quickpose.ai")!)
            }
            Button("Later", role: .cancel) { }
        } message: {
            Text("The demos need a QuickPose SDK key to run. Register for a free key at dev.quickpose.ai, then paste it into QuickPoseConfig.sdkKey in QuickPose_PickerDemoApp.swift.")
        }
    }
}

struct LandingLinkRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

struct FeatureListView: View {
    let category: FeatureCategory

    private var sections: [(name: String, items: [(title: String, features: [QuickPose.Feature])])] {
        if category.name == "Fitness" {
            return QuickPose.Feature.fitnessSections().map { section in
                (name: section.name, items: section.features.map { (title: $0.first?.displayString ?? "", features: $0) })
            }
        }
        if category.name == "Overlay Colours" {
            return [(name: "", items: QuickPose.Feature.overlayStylePresets())]
        }
        return [(name: "", items: QuickPose.Feature.allDemoFeatures(component: category.name).map { features in
            (title: category.name == "Sports" ? "Cycling/Rowing" : (features.first?.displayString ?? ""), features: features)
        })]
    }

    var body: some View {
        List {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                Section {
                    ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                        NavigationLink {
                            QuickPosePickerView(features: item.features, title: item.title)
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color("AccentColor"))
                                    .frame(width: 32)
                                Text(item.title)
                                    .font(.body.weight(.medium))
                            }
                            .padding(.vertical, 6)
                        }
                    }
                } header: {
                    if !section.name.isEmpty {
                        Text(section.name)
                    }
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
    }
}


extension EnvironmentValues {
    private struct GeometryEnvironmentKey: EnvironmentKey {
        static let defaultValue: CGSize = CGSize(width: 0, height: 0)
    }
    private struct SafeAreaInsetEnvironmentKey: EnvironmentKey {
        static let defaultValue: EdgeInsets = EdgeInsets()

    }
    var geometry: CGSize {
        get { self[GeometryEnvironmentKey.self] }
        set { self[GeometryEnvironmentKey.self] = newValue }
    }
    var safeAreaInsets: EdgeInsets {
        get { self[SafeAreaInsetEnvironmentKey.self] }
        set { self[SafeAreaInsetEnvironmentKey.self] = newValue }
    }
}
