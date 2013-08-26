namespace :bundle do

  directory 'vendor/cache' do
    sh 'unset RUBYOPT; bundle install && bundle package --all'
  end

  task :package => %w(vendor/cache)

  task :clobber do
    rm_rf 'vendor/cache'
  end
end
