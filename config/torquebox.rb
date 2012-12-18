TorqueBox.configure do
  ruby do
    version "1.8"
  end

  pool :web do
    min 2
    max 4
    type :bounded
  end
end