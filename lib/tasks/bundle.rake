namespace :bundle do

  directory 'vendor/cache' do
    sh 'unset RUBYOPT && export BUNDLE_GEMFILE=`pwd`/Gemfile &&  bundle package --all'
  end

  task :package => %w(vendor/cache)

  task :clobber do
    rm_rf 'vendor/cache'
    rm_rf 'vendor/bundle'
  end
end
