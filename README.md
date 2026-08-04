# QuickPose iOS Demo App

The official demo app for [QuickPose](https://quickpose.ai) — an iOS SDK for real-time AI pose estimation, fitness rep counting, and motion analysis, built on MediaPipe.

Pick a feature from the landing page and try it live with your camera:

| Category | What it shows |
|---|---|
| **Fitness** | 30+ exercises with automatic rep counting — squats, push-ups, lunges, bicep curls, burpees and more, grouped by muscle group. Timed exercises like planks show a hold timer. |
| **Health** | Range of motion measurement for shoulder, hip, knee, neck and back |
| **Sports** | Cycling/rowing joint angles (shoulder, elbow, hip, knee) |
| **Input** | Hands-free input: raised finger counting, thumbs up/down detection |
| **Overlay Colours** | Styled skeleton overlays — colours, line patterns, glows, shadows, outlines and image fills |
| **Measurement** | Body distance measurement, on screen or calibrated to cm |
| **Conditional** | Overlays that change colour when a joint angle crosses a threshold |
| **General** | Skeleton overlays and raw body landmarks |

All demos support switching between the front and back camera, and a share button for exporting screenshots.

## Requirements

- Xcode 15 or later
- iOS 16.1+
- A physical iPhone or iPad — pose estimation needs a real camera, so the demos don't run in the Simulator
- A free QuickPose SDK key

## Getting Started

### 1. Get the code

The app depends on the [QuickPose iOS SDK](https://github.com/quickpose/quickpose-ios-sdk) as a local Swift Package checked out **next to this repository**:

```bash
git clone https://github.com/quickpose/quickpose-ios-demo-app.git
git clone https://github.com/quickpose/quickpose-ios-sdk.git
```

Your folder layout should look like:

```
your-folder/
├── quickpose-ios-demo-app/
└── quickpose-ios-sdk/
```

### 2. Get a free SDK key

Register at [dev.quickpose.ai](https://dev.quickpose.ai) — it takes a minute and the key is free.

Paste your key into `QuickPoseConfig.sdkKey` in [`QuickPose Demo/QuickPose_PickerDemoApp.swift`](QuickPose%20Demo/QuickPose_PickerDemoApp.swift):

```swift
enum QuickPoseConfig {
    static let sdkKey = "YOUR-SDK-KEY-HERE" // paste your key here
}
```

The app reminds you on launch if the key is missing.

### 3. Run

Open `QuickPose iOS Demo App.xcodeproj`, select your device, set your signing team, and hit Run.

## Project Structure

```
QuickPose Demo/
├── QuickPose_PickerDemoApp.swift   # App entry, landing page, feature menus, SDK key config
├── QuickPosePickerView.swift       # Live camera view: overlays, rep counter, feature lists & style presets
└── Assets.xcassets                 # App icon, accent colour, overlay textures
```

Useful starting points if you're building your own app:

- `QuickPose.Feature.fitnessSections()` — the full list of rep-counted exercises
- `QuickPose.Feature.overlayStylePresets()` — overlay styling with `QuickPose.Style`
- The `onFrame` callback in `QuickPosePickerView` — reading results, rep counting with `QuickPoseThresholdCounter`, and timed holds with `QuickPoseThresholdTimer`

## Links

- 🔑 [Get a free SDK key](https://dev.quickpose.ai)
- 📖 [Documentation](https://docs.quickpose.ai)
- 💻 [QuickPose on GitHub](https://github.com/quickpose)
- 🌐 [quickpose.ai](https://quickpose.ai)

## Support

Questions or issues? Open an issue on this repo or reach out via [quickpose.ai](https://quickpose.ai).
