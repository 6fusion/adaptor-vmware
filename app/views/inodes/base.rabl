attribute :uuid
attribute :release_version
child :capabilities => :capabilities do
  attribute :name
end