rule ".class" => [".java"] do |t|
  jars = Dir['lib/java/**/*.jar'].join(':')
  sh "javac -cp ./lib/java:#{jars} -Xlint #{t.source}"
end

task :default => "lib/java/VMwareAdaptor.class"

task :server => "lib/java/VMwareAdaptor.class" do
  sh "trinidad -e development -r config.ru"
end

task :console => "lib/java/VMwareAdaptor.class" do
  sh "padrino console"
end

desc 'run specs'
task :spec do
  `rspec`
end