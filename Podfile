platform :ios, '13.0'
source 'https://github.com/CocoaPods/Specs.git'

target 'AR Haber' do
  use_frameworks!
  inhibit_all_warnings!

  pod 'Google-Mobile-Ads-SDK'
  pod 'GoogleUtilities'
  pod 'PromisesObjC'
  pod 'nanopb'
  pod 'GoogleAppMeasurement'
  pod 'GoogleUserMessagingPlatform'

  target 'AR HaberTests' do
    inherit! :search_paths
  end

  target 'AR HaberUITests' do
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
    end
  end
end 