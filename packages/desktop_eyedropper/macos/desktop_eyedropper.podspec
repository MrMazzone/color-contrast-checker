#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint desktop_eyedropper.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'desktop_eyedropper'
  s.version          = '1.0.0'
  s.summary          = 'Pick a color from anywhere on the screen.'
  s.description      = <<-DESC
Uses NSColorSampler to pick a color from anywhere on the screen.
                       DESC
  s.homepage         = 'https://color-contrast.joemazzone.net'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Joe Mazzone' => 'https://joemazzone.net' }

  s.source           = { :path => '.' }
  s.source_files = 'desktop_eyedropper/Sources/desktop_eyedropper/**/*'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'desktop_eyedropper_privacy' => ['desktop_eyedropper/Sources/desktop_eyedropper/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
