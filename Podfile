platform :ios, '10.2'
use_frameworks!

def pods
  pod 'ObjectivePGP', :git => 'https://github.com/krzyzanowskim/ObjectivePGP.git', :tag => '0.15.0'
end

target 'passKit' do
  pods
end

target 'pass' do
  pods
end

target 'passExtension' do
  pods
end

target 'passKitTests' do
  pods
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      cflags = config.build_settings['OTHER_CFLAGS'] || ['$(inherited)']
      cflags << '-fembed-bitcode'
      config.build_settings['OTHER_CFLAGS'] = cflags
    end
  end
end
