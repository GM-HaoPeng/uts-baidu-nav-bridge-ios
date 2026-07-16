# UtsBaiduNavBridge

A lightweight Objective-C module bridge that makes the Baidu iOS Navigation SDK
callable from Swift and UTS without exposing Baidu's non-modular headers to the
consumer target.

The repository contains bridge source code only. It does not redistribute Baidu
SDK binaries, resource bundles, credentials, or application keys. CocoaPods
downloads the pinned official dependency during the consuming app build.

## Dependency

- `BaiduNaviKit-All/TTS` `6.6.7`
- iOS 12.0 or later

The TTS subspec transitively includes the Navi, Map, and Base subspecs.

## Installation

```ruby
pod 'UtsBaiduNavBridge',
    :git => 'https://github.com/GM-HaoPeng/uts-baidu-nav-bridge-ios.git',
    :tag => '0.1.6'
```

For a DCloud UTS plugin, add the same repository and tag under
`dependencies-pods` in `utssdk/app-ios/config.json`.

## Swift

```swift
import UtsBaiduNavBridge

let marker = UtsBaiduNavBridge.marker()
let version = UtsBaiduNavBridge.sdkVersion()
```

Call `setAgreePrivacy(true)` only after the application has obtained the user's
privacy consent and before initializing the navigation SDK.

## Scope

Version `0.1.0` provides the module boundary and minimal lifecycle APIs:

- module marker and SDK version
- privacy consent forwarding
- navigation SDK initialization and app-key authorization
- TTS authorization
- service state and stop operation

Route planning, navigation UI, and navigation event adapters are intentionally
added in later versions after this module is verified in DCloud cloud packaging.

Version `0.1.1` also enables dead stripping in the consuming target. DCloud's
UTS iOS framework build disables dead stripping in Debug builds, which otherwise
links duplicate `pb_tools.o` symbols from Baidu MapSDK and NaviSDK 6.6.7.

Version `0.1.2` aligns navigation initialization with Baidu's official demo by
passing `nil` initialization parameters, skips duplicate initialization when the
service is already ready, and adds native stage logging plus callback timeouts.

Version `0.1.3` adds the driving route-plan and official SDK UI session adapter,
including real/simulated navigation, lifecycle controls, rerouting, voice and
camera controls, progress events, native failures, and deterministic timeouts.

Version `0.1.4` aligns ordinary driving route-plan dispatch with the official
demo's nil userInfo path and reports route-manager acceptance diagnostics.

Version `0.1.5` upgrades the official Baidu navigation CocoaPod dependency from
6.6.7 to 7.1.0 after 6.6.7 accepted route nodes but did not start route planning.

Version `0.1.6` honors `navigationUiMode`: SDK mode presents Baidu's navigation
UI, while no-UI mode starts and stops only the native navigation core.

## License

The bridge source is available under the MIT License. Baidu SDK components remain
subject to Baidu's own terms and are not included in this repository.
