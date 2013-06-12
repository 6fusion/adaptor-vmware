## Environment locations.
$integration                = "https://console-integration.6fusion.com"
$signoff                    = "https://console-signoff.6fusion.com"
$local                      = "http://localhost:3000"
$staging                    = "https://console-staging.6fusion.com"
$production                 = ""
$whiskey                    = "https://console.6fusion.whiskey"
$vodka                      = "https://console.6fusion.vodka"
$gin                        = "https://console.6fusion.gin"

## Flags, configuration file loaders and all sorts of shenanigans.
#config          = File.dirname(__FILE__) + '/config/' + Padrino.env + '.yml'
#$config_values  = YAML.load(ERB.new(File.read(config)).result)