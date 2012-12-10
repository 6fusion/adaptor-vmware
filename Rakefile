rule ".class" => [".java"] do |t|
  sh "javac -Xlint #{t.source}"
end

#Dir["lib/java/*.java"].each do |file|
#  file "lib/java/#{file}.class"
#end

task :default => "lib/java/VMwareInventory.class"