class AdaptorVMware < Padrino::Application
  register Padrino::Rendering
  register Padrino::Mailer
  register Padrino::Helpers

  enable :sessions

  class ErrorDescription
    attr_accessor :code, :description

    def initialize(code, description)
      self.code, self.description = code, description
    end
  end

  ##
  # Caching support
  #
  # register Padrino::Cache
  # enable :caching
  #
  # You can customize caching store engines:
  #
  #   set :cache, Padrino::Cache::Store::Memcache.new(::Memcached.new('127.0.0.1:11211', :exception_retry_limit => 1))
  #   set :cache, Padrino::Cache::Store::Memcache.new(::Dalli::Client.new('127.0.0.1:11211', :exception_retry_limit => 1))
  #   set :cache, Padrino::Cache::Store::Redis.new(::Redis.new(:host => '127.0.0.1', :port => 6379, :db => 0))
  #   set :cache, Padrino::Cache::Store::Memory.new(50)
  #   set :cache, Padrino::Cache::Store::File.new(Padrino.root('tmp', app_name.to_s, 'cache')) # default choice
  #

  ##
  # Application configuration options
  #
  # set :raise_errors, true       # Raise exceptions (will stop application) (default for test)
  # set :dump_errors, true        # Exception backtraces are written to STDERR (default for production/development)
  # set :show_exceptions, true    # Shows a stack trace in browser (default for development)
  # set :logging, true            # Logging in STDOUT for development and file for production (default only for development)
  # set :public_folder, "foo/bar" # Location for static assets (default root/public)
  # set :reload, false            # Reload application files (default in development)
  # set :default_builder, "foo"   # Set a custom form builder (default 'StandardFormBuilder')
  # set :locale_path, "bar"       # Set path for I18n translations (default your_app/locales)
  # disable :sessions             # Disabled sessions by default (enable if needed)
  # disable :flash                # Disables sinatra-flash (enabled by default if Sinatra::Flash is defined)
  # layout  :my_layout            # Layout can be in views/layouts/foo.ext or views/foo.ext (default :application)
  #
  configure :development do
    disable :show_exceptions, :raise_errors
  end

  def render_json_error(code)
    @error = ErrorDescription.new(code,env['sinatra.error'].to_s)
    logger.info "code = #{@error.code}, description=#{@error.description}"
    render('errors/error')
  end

  ##
  # You can manage errors like:
  error Exceptions::Forbidden do
    halt 403
  end

  error Exceptions::NotFound do
    halt 404
  end

  error Exceptions::MethodNotAllowed do
    halt 405
  end

  error Exceptions::Unrecoverable do
    halt 500
  end

  error Exceptions::NotImplemented do
    halt 501
  end

  error Exceptions::UnprocessableEntity do
    halt 422
  end

  error 403 do
    render_json_error(403)
  end

  error 404 do
    render_json_error(404)
  end

  error 405 do
    render_json_error(405)
  end

  error 422 do
    render_json_error(422)
  end

  error 500 do
    render_json_error(500)
  end

  error 501 do
    render_json_error(501)
  end
end