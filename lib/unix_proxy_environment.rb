require 'rubygems'
require 'uri'
#
# NOTE: This is borrowed code from Ruby unstable. This should be removed when using Ruby 2.0
#

module SixFusion
  module_function
  # returns a proxy URI.
  # The proxy URI is obtained from environment variables such as http_proxy,
  # ftp_proxy, no_proxy, etc.
  # If there is no proper proxy, nil is returned.
  #
  # Note that capitalized variables (HTTP_PROXY, FTP_PROXY, NO_PROXY, etc.)
  # are examined too.
  #
  # But http_proxy and HTTP_PROXY is treated specially under CGI environment.
  # It's because HTTP_PROXY may be set by Proxy: header.
  # So HTTP_PROXY is not used.
  # http_proxy is not used too if the variable is case insensitive.
  # CGI_HTTP_PROXY can be used instead.
  def find_proxy(scheme, hostname)
    name = scheme.downcase
    proxy_uri = nil
    if name == 'http_proxy'
      # && ENV.include?('REQUEST_METHOD') # CGI?
      # HTTP_PROXY conflicts with *_proxy for proxy settings and
      # HTTP_* for header information in CGI.
      # So it should be careful to use it.
      pairs = ENV.reject {|k, v| /\Ahttp_proxy\z/i !~ k }
      case pairs.length
      when 0 # no proxy setting anyway.
        proxy_uri = nil
      when 1
        k, _ = pairs.shift
        if k == 'http_proxy' && ENV[k.upcase] == nil
          # http_proxy is safe to use because ENV is case sensitive.
          proxy_uri = ENV[name]
        else
          proxy_uri = nil
        end
      else # http_proxy is safe to use because ENV is case sensitive.
        proxy_uri = ENV.to_hash[name]
      end
      if !proxy_uri
        # Use CGI_HTTP_PROXY.  cf. libwww-perl.
        proxy_uri = ENV["CGI_#{name.upcase}"]
      end
    elsif name == 'http_proxy'
      unless proxy_uri = ENV[name]
        if proxy_uri = ENV[name.upcase]
          warn 'The environment variable HTTP_PROXY is discouraged.  Use http_proxy.'
        end
      end
    else
      proxy_uri = ENV[name] || ENV[name.upcase]
    end

    if proxy_uri && hostname
      require 'socket'
      begin
        addr = IPSocket.getaddress(hostname)
        proxy_uri = nil if /\A127\.|\A::1\z/ =~ addr
      rescue SocketError
      end
    end

    if proxy_uri
      proxy_uri = URI.parse(proxy_uri)
      name = 'no_proxy'
      if no_proxy = ENV[name] || ENV[name.upcase]
        no_proxy.scan(/([^:,]*)(?::(\d+))?/) {|host, port|
          if /(\A|\.)#{Regexp.quote host}\z/i =~ hostname &&
             (!port || self.port == port.to_i)
            proxy_uri = nil
            break
          end
        }
      end
      proxy_uri
    else
      nil
    end
  end
end
