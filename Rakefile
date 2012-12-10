rule ".class" => [".java"] do |t|
  sh "javac -Xlint #{t.source}"
end

task :default => "lib/java/VMwareInventory.class"

task :server => "lib/java/VMwareInventory.class" do
  sh "padrino start"
end

task :console => "lib/java/VMwareInventory.class" do
  sh "padrino console"
end