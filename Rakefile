task :server do
  sh "trinidad -e development -r config.ru"
end

task :console do
  sh "padrino console"
end

task :spec do
  puts `rspec`
end
