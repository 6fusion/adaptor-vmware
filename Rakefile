$branch = `git branch --no-color 2> /dev/null`.chomp.split("\n").grep(/^[*]/).first[/(\S+)$/, 1] rescue ""
$component = `git config --get remote.origin.url`.chomp[/git@github.com:6fusion\/([\w-]+)/, 1]

Dir['lib/tasks/*.rake'].each do |f|
  import f
end

desc 'start trinidad'
task :server do
  sh "trinidad -e development -r config.ru"
end

desc 'console'
task :console do
  sh "padrino console"
end

desc 'specs'
task :spec do
  puts `rspec`
end
