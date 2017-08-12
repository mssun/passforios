platform :ios, '10.2'
use_frameworks!

target 'passKit' do
    pod 'ObjectivePGP', :git => 'https://github.com/krzyzanowskim/ObjectivePGP.git'
    target 'pass' do
        inherit! :search_paths
    end
    target 'passExtension' do
        inherit! :search_paths
    end
    target 'passKitTests' do
        inherit! :search_paths
    end
end
