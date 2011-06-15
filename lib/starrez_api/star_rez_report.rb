require 'httparty'
class StarRezReport
  include HTTParty
  base_uri PLUGIN_CONFIG['base_uri']
  attr_accessor :name, :results
    
  def self.find_by_id(entry, options = {})
    if entry.blank?
      raise IOError, "Must include a report ID to search"
    end
    conditions = options[:conditions].blank? ? '' : "?#{self.get_condition_string(options[:conditions])}"
    url = "#{base_uri}/getreportbyid/#{entry}.xml/#{conditions}"
    response = get(url)
    if options[:return].eql? :response
      return response
    else
      return self.parse_response(response)
    end
  end
  
  def self.find_by_name(name, options = {})
    if name.blank?
      raise IOError, "Must include a report name"
    end
    conditions = options[:conditions].blank? ? '' : "?#{self.get_condition_string(options[:conditions])}"
    url = "#{base_uri}/getreportbyname/#{URI::escape(name.to_s)}.xml/#{conditions}"
    response = get(url)
    if options[:return].eql? :response
      return response
    else
      return self.parse_response(response)
    end
  end
    
  private
  # Parse the response from the API
  def self.parse_response(response)
    if response.code.eql? 200
      report = StarRezReport.new
      report.name = response.keys.first
      if response[report.name].blank?
        report.results = []
      else
        if response[report.name]["Record"].is_a? Hash
          report.results = [response[report.name]["Record"]]
        else
          report.results = response[report.name]["Record"]
        end
      end
      return report
    elsif response.code.eql? 403
      raise SecurityError, "Access Denied to API"
    else
      return false
    end
  end
  
  # Coditions Clean-up by Dan
  # Example:
  # find(:all, :conditions => { :column_name => value, :column_name => { :operator => value } })
  def self.get_condition_string(conditions)
    queries = Array.new
    if conditions.is_a?(Hash)
      conditions.each_pair do |column, value|
        query = column.to_s.camelize
        if value.is_a?(Hash)
          query += "[_operator%3D#{value.keys.first.to_s}]=#{self.parse_value(value[value.keys.first])}"
        else
          query += "=#{self.parse_value(value)}"
        end
        queries << query
      end
      return queries.join('&')
    else
      raise ArgumentError, "Condition needs to be a hash of values, Please review the source code"
    end
  end
    
  #Just a quick method used in get_condition_string that would have been repeated
  #Just takes the array and converts it into a formatted string for StarRezAPI
  def self.parse_value(values)
    if values.is_a?(Array)
      return URI::encode(values.join(','))
    else
      return URI::encode(values.to_s)
    end    
  end
end