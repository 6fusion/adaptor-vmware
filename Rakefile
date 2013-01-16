rule ".class" => [".java"] do |t|
  jars = Dir['lib/java/**/*.jar'].join(':')
  sh "javac -cp ./lib/java:#{jars} -Xlint #{t.source}"
end

task :default => "lib/java/VMwareInventory.class"

task :server => "lib/java/VMwareInventory.class" do
  sh "trinidad -e development -r config.ru"
end

task :console => "lib/java/VMwareInventory.class" do
  sh "padrino console"
end