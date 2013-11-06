# NOTE: we don't use the Rake::PackageTask because it doesn't detect files that were generated after rake started, which makes
# it not so useful for generating packages when there are generated files.

package_path     = 'pkg'
package_dir_path = "#{package_path}/#{$component}"

namespace :package do

  directory package_dir_path

  file package_dir_path => %w(vendor/cache) do
    files = FileList.new do |fl|
      fl.add 'app/**/*'
      fl.add 'config/**/*'
      fl.add 'vendor/**/*'
      fl.add 'models/**/*'
      fl.add 'public/**/*'
      fl.add 'log'
      fl.add 'lib/**/*'
      fl.add 'Gemfile*'
      fl.add 'Capfile'
      fl.add 'config.ru'
      fl.add 'Rakefile'
      fl.add 'VERSION'
    end

    files.each do |fn|
      f    = File.join(package_dir_path, fn)
      fdir = File.dirname(f)
      mkdir_p(fdir) if !File.exist?(fdir)
      if File.directory?(fn)
        mkdir_p(f)
      else
        rm_f f
        safe_ln(fn, f)
      end
    end

  end

  file "#{package_path}/#{$component}-#{$branch}.tar" => [package_dir_path] do |task|
    chdir(package_path) do
      sh "tar -cvf #{File.basename(task.name)} #{$component}"
    end
    puts "Package Generated at #{task.name}"
  end

  task :clobber => 'bundle:clobber' do
    rm_rf package_path
  end

  task :clean => 'bundle:clobber' do
    rm_rf package_dir_path
  end

  task :default => "#{package_path}/#{$component}-#{$branch}.tar"

end

desc 'generate a package for this product'
task :package => 'package:default'

task :repackage => ['package:clobber', 'package:default']
