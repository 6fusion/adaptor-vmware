require 'torquebox-cache'

class ResultCache
  def initialize
    @cache = TorqueBox::Infinispan::Cache.new( :name => 'results' )
  end

  def self.session_id
    UUID.new.generate
  end

  def put(key, value)
    @cache.put(key, Marshal.dump(value))
  end

  def get(key)
    value = @cache.get(key)
    Marshal.load(value) rescue value
  end

  # delegate other calls to the underlying cache
  def method_missing(sym, *args, &block)
    @cache.send(sym, *args, &block)
  end

end