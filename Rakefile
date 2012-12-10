rule ".class" => [".java"] do |t|
  sh "javac -Xlint #{t.source}"
end

task :default => "lib/java/VMwareInventory.class"