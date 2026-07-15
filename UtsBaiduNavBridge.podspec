Pod::Spec.new do |s|
  s.name = 'UtsBaiduNavBridge'
  s.version = '0.1.1'
  s.summary = 'A small Objective-C module bridge for Baidu iOS Navigation SDK.'
  s.description = <<-DESC
Exposes bridge-safe Foundation APIs for Swift and UTS while keeping Baidu
Navigation SDK Objective-C headers out of the consuming module interface.
  DESC
  s.homepage = 'https://github.com/GM-HaoPeng/uts-baidu-nav-bridge-ios'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'GM-HaoPeng' => 'GM-HaoPeng@users.noreply.github.com' }
  s.source = {
    :git => 'https://github.com/GM-HaoPeng/uts-baidu-nav-bridge-ios.git',
    :tag => s.version.to_s
  }

  s.platform = :ios, '12.0'
  s.requires_arc = true
  s.static_framework = true
  s.module_name = 'UtsBaiduNavBridge'

  s.source_files = 'Sources/**/*.{h,m}'
  s.public_header_files = 'Sources/UtsBaiduNavBridge.h'
  s.frameworks = 'Foundation', 'UIKit'
  s.dependency 'BaiduNaviKit-All/TTS', '6.6.7'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -Wl,-dead_strip'
  }
end
