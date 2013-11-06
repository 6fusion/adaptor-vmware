require 'semantic'

def read_version
  Semantic::Version.new(File.read('VERSION').chomp)
end

def write_version(version)
  File.open('VERSION', 'w+') do |f|
    f.write(version)
  end
  puts "New Version: #{version}"
end

namespace :version do

  task :default do
    version = read_version
    puts "Current Version: #{version}"
  end

  task :bump_major do
    version       = read_version
    version.major += 1
    version.minor = 0
    version.patch = 0
    write_version(version)
  end

  task :bump_minor do
    version       = read_version
    version.minor += 1
    version.patch = 0
    write_version(version)
  end

  task :bump_patch do
    version       = read_version
    version.patch += 1
    write_version(version)
  end
end

task :version => 'version:default'
