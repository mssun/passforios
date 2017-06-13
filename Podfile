def generate_modulemap(name, path)
    f = File.new(File.join("#{path}/module.modulemap"), "w+")
    module_name = "#{name}"
    while(module_name["+"])
        module_name["+"] = "_"
    end
    f.puts("module #{module_name} {")
    f.puts("    umbrella header \"#{name}_umbrella.h\"")
    f.puts("    export *")
    f.puts("}")
end

def generate_umbrella(name, path)
    f = File.new(File.join("#{path}/#{name}_umbrella.h"), "w+")
    f.puts("#import <Foundation/Foundation.h>")
    Dir.chdir(path) {
        Dir.glob("**/*.h").map {
            |filename| f.puts("#import \"#{filename}\"")
        }
    }
end

post_install do |installer|
    require "fileutils"
    headers_path = "#{Dir::pwd}/Pods/Headers/Public/"
    
    installer.pods_project.targets.each do |target|
        target_header_path = "#{headers_path}#{target.product_name}"
        if File.exist?(target_header_path)
            filename = target.product_name
            if filename != "." and filename != ".."
                generate_umbrella(filename, target_header_path)
                generate_modulemap(filename, target_header_path)
            end
        end
    end
end

target 'pass' do
  pod 'ObjectivePGP', :git => 'https://github.com/mssun/ObjectivePGP.git'
  target 'passKit' do
    inherit! :search_paths
  end
  target 'passextension' do
    inherit! :search_paths
  end
end
