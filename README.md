# UtsBaiduNavBridge

A lightweight Objective-C module bridge that makes the Baidu iOS Navigation SDK
callable from Swift and UTS without exposing Baidu's non-modular headers to the
consumer target.

The repository contains bridge source code only. It does not redistribute Baidu
SDK binaries, resource bundles, credentials, or application keys. CocoaPods
downloads the pinned official dependency during the consuming app build.

## Dependency

- `BaiduNaviKit-All/TTS` `7.1.0`
- iOS 12.0 or later

The TTS subspec transitively includes the Navi, Map, and Base subspecs.

Version `0.1.22` makes NavSDK the sole iOS system-speech owner. Pass
`navigationVoice.ttsEngineType = "system"` to set NavSDK `useSystemTTS = YES`;
the SDK uses iOS system TTS without Baidu TTS credentials. The bridge sound
delegate observes instruction text and completion events but does not synthesize
the received text again. `external` only emits instruction events, while
`baiduBuiltin` keeps the official built-in Baidu TTS path.

## Installation

```ruby
pod 'UtsBaiduNavBridge',
    :git => 'https://github.com/GM-HaoPeng/uts-baidu-nav-bridge-ios.git',
    :tag => '0.1.22'
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

Version `0.1.7` adds a combined navigation and built-in TTS authorization entry.

Version `0.1.8` makes the combined authorization sequence deterministic:
`initNaviService` succeeds first, `authorizeNaviAppKey` completes successfully
second, and only then does `authorizeTTSAppId` start. This follows Baidu's
documented requirement that SDK authorization precede TTS authorization.

Version `0.1.9` adds iOS system speech through `BNNaviSoundDelegate` and
`AVSpeechSynthesizer`.

Version `0.1.10` prevents dense navigation instructions from repeatedly
interrupting the active system utterance. It keeps one latest pending
instruction and reuses the active audio session until navigation stops.

Version `0.1.11` isolates system speech from the navigation SDK's shared audio
session by setting `AVSpeechSynthesizer.usesApplicationAudioSession` to `NO` on
iOS 13 and later. iOS 12 falls back to the navigation-specific
`AVAudioSessionModeVoicePrompt` with ducking and spoken-audio interruption
options. This prevents an utterance from remaining paused when NavSDK changes
the application's audio session.

Version `0.1.18` returns to the `0.1.11` audio and queueing design and adds only
pre-synthesis punctuation normalization. It intentionally excludes the 180 ms
transition timer from `0.1.12`, the rendered PCM player path from `0.1.13` to
`0.1.15`, and the application-shared audio-session changes from `0.1.16` and
`0.1.17`.

Version `0.1.19` keeps the complete `0.1.18` runtime path and adds only a 120 ms
`AVSpeechUtterance.preUtteranceDelay` on iOS 13 and later. This is an utterance
onset guard, not a bridge transition timer: pending speech is still handed to
the synthesizer immediately, and the bridge still avoids rendered PCM and the
application-shared audio session.

Version `0.1.20` removes the ineffective `0.1.19` onset delay and applies the
official NavSDK `useSystemTTS` strategy before route planning. This makes system
and external speech explicitly use the custom TTS callback path while preserving
the `0.1.18` direct synthesizer, dedicated-session, queueing, and punctuation
behavior. Built-in Baidu TTS remains available through `useSystemTTS = NO`.

Version `0.1.21` fixes the BaiduNaviKit-All 7.1.0 sound-manager crash exposed by
`0.1.20`. It registers the sound delegate before changing `useSystemTTS`, keeps
both operations before route planning, and catches Objective-C exceptions from
the SDK so an incompatible sound component returns a structured navigation
failure instead of terminating the host app.

Version `0.1.22` fixes duplicate system speech in `0.1.21`. Baidu's
`useSystemTTS = YES` means that NavSDK itself speaks through iOS system TTS; it
does not merely route text to the custom delegate. The bridge therefore enables
the flag only for `system` mode and does not call its own `AVSpeechSynthesizer`
for delegate text.

## License

The bridge source is available under the MIT License. Baidu SDK components remain
subject to Baidu's own terms and are not included in this repository.
