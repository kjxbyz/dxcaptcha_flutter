#
# 顶象无感验证码 Flutter 插件（iOS）。
#
# SDK 说明：
#   - Frameworks/dx-captcha.xcframework：顶象验证码核心框架（必选）
#   - Frameworks/DXCaptcha.bundle：验证码前端资源包（必选，缺省会白屏）
#   - 设备指纹 DXRiskStatic.framework 为可选依赖，未使用可忽略
#
Pod::Spec.new do |s|
  s.name             = 'dxcaptcha_flutter'
  s.version          = '0.1.0'
  s.summary          = '顶象无感验证码 Flutter 插件'
  s.description      = <<-DESC
顶象无感验证码（DingXiang Captcha）Flutter 插件，支持 iOS / Android，
提供嵌入组件与全屏弹窗两种接入方式。
                       DESC
  s.homepage         = 'https://www.dingxiang-inc.com/docs/detail/captcha'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'PCXX' => 'dev@example.com' }
  s.source           = { :path => '.' }

  s.source_files        = 'dxcaptcha_flutter/Sources/dxcaptcha_flutter/**/*.{h,m}'
  s.public_header_files = 'dxcaptcha_flutter/Sources/dxcaptcha_flutter/DxcaptchaFlutterPlugin.h'

  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # 关键：必须为 static framework。
  # 顶象 SDK 通过 [NSBundle mainBundle] 在 app 包根目录查找 DXCaptcha.bundle，
  # dynamic framework pod 会把 resources 打进自身 framework 包内导致 SDK 找不到
  # 资源（WebView 加载空白 → 白屏）；static pod 的 resources 会被 CocoaPods
  # 直接拷贝到 app bundle 根目录，与官方接入方式一致。
  s.static_framework = true

  # 顶象 SDK：xcframework 提供切片二进制，bundle 提供验证码前端资源。
  #
  # Flutter 通过 .symlinks/plugins 符号链接引入本地插件，CocoaPods 解析
  # vendored_frameworks 时会把链接层级重复叠加，因此这里额外用 PODS_TARGET_SRCROOT
  # 显式声明搜索路径与链接参数，保证二进制一定被链接进来。
  s.vendored_frameworks = 'Frameworks/dx-captcha.xcframework'
  s.resources           = 'Frameworks/DXCaptcha.bundle'
  s.preserve_paths      = 'Frameworks/**'

  s.frameworks = 'UIKit', 'WebKit', 'Foundation', 'CoreGraphics'
  s.libraries  = 'z', 'resolv', 'c++'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '$(inherited) -framework "dx-captcha"',
    'FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*]' =>
      '$(inherited) "${PODS_TARGET_SRCROOT}/Frameworks/dx-captcha.xcframework/ios-arm64_armv7"',
    'FRAMEWORK_SEARCH_PATHS[sdk=iphonesimulator*]' =>
      '$(inherited) "${PODS_TARGET_SRCROOT}/Frameworks/dx-captcha.xcframework/ios-arm64_x86_64-simulator"',
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -framework "dx-captcha"',
    'FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*]' =>
      '$(inherited) "${PODS_ROOT}/../.symlinks/plugins/dxcaptcha_flutter/ios/Frameworks/dx-captcha.xcframework/ios-arm64_armv7"',
    'FRAMEWORK_SEARCH_PATHS[sdk=iphonesimulator*]' =>
      '$(inherited) "${PODS_ROOT}/../.symlinks/plugins/dxcaptcha_flutter/ios/Frameworks/dx-captcha.xcframework/ios-arm64_x86_64-simulator"',
  }

  s.swift_version = '5.0'
end
