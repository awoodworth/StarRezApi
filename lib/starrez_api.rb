# StarRez REST Web Services and Report API

# Load our configuration
if File.exists?(File.join(Rails.root,"config","starrez.yml"))
  config_path = File.join(Rails.root,"config","starrez.yml")
else
  config_path = File.dirname(__FILE__) + "/starrez.yml"
end
STARREZ_CONFIG = YAML.load_file(config_path)[Rails.env]

# Check for required gems
begin
  require 'httparty'
  HTTParty
rescue Exception => e
  puts "HTTParty is a required GEM for this plugin. Solve by typing: gem install httparty"
end
  
# Load our Plugin files
require 'starrez_api/object'
require 'starrez_api/star_rez_api'
require 'starrez_api/star_rez_report'
require 'starrez_api/star_rez_account'