rule ".class" => [".java"] do |t|
  sh "javac -cp ./lib/java:./lib/java/vijava:./lib/java/vijava/dom4j-1.6.1.jar:./lib/java/vijava/vijava5120121125.jar -Xlint #{t.source}"
end

task :default => "lib/java/VMwareInventory.class"

task :server => "lib/java/VMwareInventory.class" do
  sh "padrino start"
end

task :console => "lib/java/VMwareInventory.class" do
  sh "padrino console"
end