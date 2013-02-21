# rule ".class" => [".java"] do |t|
#   jars = Dir['lib/java/**/*.jar'].join(':')
#   sh "javac -cp ./lib/java:#{jars} -Xlint #{t.source}"
#   sh "mkdir lib/java/sixfusion" if Dir["lib/java/sixfusion"].nil?
#   sh "cd lib/java/src && jar -cvf ../sixfusion/vmware-adaptor.jar com/sixfusion/VMwareAdaptor.class"
# end

# task :default => "lib/java/com/sixfusion/VMwareAdaptor.class"

# task :server => "lib/java/src/com/sixfusion/VMwareAdaptor.class" do
#   sh "trinidad -e development -r config.ru"
# end

task :server do
  sh "trinidad -e development -r config.ru"
end

# task :console => "lib/java/src/com/sixfusion/VMwareAdaptor.class" do
#   sh "padrino console"
# end

# task :spec => "lib/java/src/com/sixfusion/VMwareAdaptor.class" do
#   puts `rspec`
# end
