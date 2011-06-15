require 'httparty'
require 'xmlsimple'

module StarRezApi  
  include HTTParty
  base_uri PLUGIN_CONFIG['base_uri']

  def self.included receiver
    receiver.extend ClassMethods
  end

  module ClassMethods
    def first
      results = find(:first)
    end

    def url
      "#{StarRezApi::base_uri}/select/#{self.name.gsub(/.*\:\:/,'').downcase}.xml/?_top=1"
    end

    def what_am_i?
      "#{self.class.name}"
    end

    def class_name
      self.name.gsub(/.*\:\:/,'')
    end
    
     def populate_variables(hash, related_tables=[])
        self.instance_variable_set("@original_hash",hash)
        hash.each do |k,v|
          if related_tables.include? k.to_s
            children = Array.new
            v = [v] unless v.is_a? Array # This handles the instance of a single-child
            v.each do |child|
              new_child = self.clone
              new_child.populate_variables(child)
              children << new_child
            end
            new_k = k.to_s.underscore.pluralize
            self.instance_variable_set("@#{new_k}", children)
            meta_def new_k do
              self.instance_variable_get("@#{new_k}")
            end
            meta_def "#{new_k}=" do |v|
              self.instance_variable_set("@#{new_k}",v)
            end
          elsif k.is_a?(Hash)
            # Ignore sub-objects
          else
            unless k.blank?
              k = k.to_s.underscore
              self.instance_variable_set("@#{k}",v)
              meta_def k do
                self.instance_variable_get("@#{k}")
              end
              meta_def "#{k}=" do |v|
                self.instance_variable_set("@#{k}",v)
              end
            end
          end
        end
      end
  
    def id
      self.send "#{self.class_name.underscore}_id"
    end
       
    def changed
      changed_attributes = Hash.new
      self.instance_variable_get("@original_hash").each do |k,v|
        k = k.to_s.underscore
        current_value = self.send(k.to_sym)
        unless current_value.eql? v
          changed_attributes[k.to_sym] = [v, current_value]
        end
      end
      return changed_attributes
    end
   
    def changed?
      self.changed.size > 0
    end
   
    def save
      if self.changed?
        response = StarRezApi::post("#{StarRezApi::base_uri}/update/#{self.class_name}/#{self.id}", :body => self.build_query(self.changed))
        if response.code.eql? 200
          original_hash = self.instance_variable_get("@original_hash")
          self.build_query(self.changed).keys.each do |attribute|
            original_hash[attribute.to_s] = self.send(attribute.to_s.underscore.to_sym)
          end
          self.instance_variable_set("@original_hash",original_hash)
          return true
        else
          return response
        end
      else
        warn "[WARN] Nothing to save"
        return false
      end
    end
    
    def create(attribute_hash = {}, options ={})
      formatted_hash = Hash.new
      attribute_hash.each_pair { |column, value| formatted_hash[column.to_s.camelize.to_sym] = value }
      results = StarRezApi::post("#{StarRezApi::base_uri}/create/#{self.class_name}", :body => formatted_hash)
      if results.code.eql? 200
        if options[:return].eql? :boolean
          return true
        else
          response = XmlSimple.xml_in(results.body)
          new_id = response["entry"][0]["content"]
          return self.find new_id
        end
      elsif results.code.eql? 400
        return false
      else
        return false
      end
    end
    
   
    def all(page_index = 1, page_size = 50)
      return find(:all, {:size => page_size, :page => page_index})
    end

    
    
    # Find objects via the API interface
    # Returns an object defined on demand by the API result
    #
    # An Object ID or one of the following symbols (:all, :first) must be the first argument
    # +id+::          The ID of the Object your are searching
    # +:all+::        Returns an array of objects
    # +:first+::      Returns the first matched object  
    #
    #
    # The following options are not required but can be used to refine the search
    # +:conditions+::  Field-Value Pairs
    # +:page+::        The index page for pagination
    # +:size+::        The number of results returned per page
    # +:fields+::      An array of field names to return
    # +:include+::     Include related tables (this only works if you go from parent->child)
    # +:order+::       An array of field names to order the response by.
    # +:limit+::       The number of results to return
    # 
    # The +conditions+ option should be a hash with key-value pairs related to the search
    # requirements. Due to the nature of the StarRez API, there is an additional complexity
    # of seach operands. For this reason the conditions can be in either of the following
    # two formats:
    #
    #  { :column_name => value }
    #
    #  { :column_name => { :operand => value } }
    #
    #  Available Operands are:
    #  
    #  +ne+::     Not Equals
    #  +gt+::     Greater Than
    #  +lt+::     Less Than
    #  +gte+::    Greater Than or Equal To
    #  +lte+::    Less Than or Equal To
    #  +c+::      Contains
    #  +nc+::     Not Contains
    #  +sw+::     Starts With
    #  +nsw+::    Not Starts With
    #  +ew+::     Ends With
    #  +new+::    Not Ends With
    #  +in+::     Value is in (comma separated integer list)
    #  +notin+::  Value is not in (comma separated integer list)
    #
    # The +fields+ option should be an Array of either symbols or strings which refer to a
    # column in the field. There is no error checking prior to the submission, so an invalid
    # field name will result in an error.
    #
    # The +include+ option should be an Array of either symbols or strings which refer to a
    # related tables in the database. There is no error checking and an invalid relationship
    # will result in a failure. This will create an instance variable of an Array of the 
    # returned objects which will be accessible by a method with the table name pluralized.
    #
    # The +order+ option should be an array of fields which the response is ordered by. If
    # You wish to search by descending order, use a key value of :desc. For example: 
    # :order => [:name_last, :name_first => :desc]
    #
    #
    # Usage:
    #
    #   # Search for a single Entry with the ID of 1234
    #   Entry.find(1234)
    #
    #   # Search for all entries with the last name 'Smith'
    #   Entry.find(:all, :conditions => { :name_last => "Smith"})
    #
    #   # Search for all entries with the last name that starts with 'Sm' and only return first and last names
    #   Entry.find(:all, :conditions => { :name_last => { :sw => "Sm" } }, :fields => [:name_last, :name_first])
    #
    #   # Search for all rooms on a specific floor ('654')
    #   RoomLocationFloorSuite(654, :include => [:room])
    

    def find(entry, options = {})
      options[:size] ||= 50
      options[:page] = options[:page].blank? || options[:page] == 1 ? 0 : options[:page] * options[:size]
      query_array = Array.new
      unless options[:conditions].blank?
        query_array << get_condition_string(options[:conditions]) 
      end
      if entry.is_a?(Symbol)
        get_url = "#{StarRezApi::base_uri}/select/#{self.class_name}.xml/"
      else
        get_url = "#{StarRezApi::base_uri}/select/#{self.class_name}.xml/#{entry}"
      end
      if entry.eql? :first        
        query_array << "_top=1"
      elsif entry.eql? :all
        query_array << "_pageIndex=#{options[:page]}"
        query_array << "_pageSize=#{options[:size]}"  
      end
      unless options[:fields].blank?
        fields = Array.new
        options[:fields].each { |f| fields << f.to_s.camelize }
        query_array << "_fields=#{fields.join(',')}"
      end
      tables = Array.new
      unless options[:include].blank?
        options[:include].each { |t| tables << t.to_s.camelize }
        query_array << "_relatedtables=#{tables.join(',')}"
      end
      unless options[:order].blank?
        order = Array.new
        options[:order].each { |o| order << (options[:order][o].eql? :desc) ? "#{o.to_s.camelize}.desc" : "#{o.to_s.camelize}"}
        query_array << "_orderby=#{order.join(',')}"
      end
      unless options[:limit].blank?
        query_array << "_top=#{options[:limit]}"
      end
      get_url += "?#{query_array.join('&')}"
      results = StarRezApi::get(get_url)
      if results.response.is_a?(Net::HTTPNotFound)
        return nil
      elsif results.code.eql? 403
        raise SecurityError, "Access Denied to API"
      elsif options[:return].eql? :response
        return results
      elsif results.code.eql? 200
        ret = results["Results"][self.class_name]
      else
        return results
      end
      if ret.is_a?(Hash)
        self.populate_variables(ret,tables)
        if entry.eql? :all
          return [self]
        else        
          return self
        end
      else
        results = Array.new
        ret.each do |entry_hash|
          new_entry = self.clone
          new_entry.populate_variables(entry_hash,tables)
          results << new_entry
        end
        return results
      end
    end
    
     
    def build_query(hash)
      query = Hash.new
      hash.keys.each do |attribute|
        query[attribute.to_s.camelize.to_sym] = self.send(attribute)
      end
      return query
    end
    
    private 
    
    #Just a quick method used in get_condition_string that would have been repeated
    #Just takes the array and converts it into a formatted string for StarRezAPI
    def parse_value(values)
      if values.is_a?(Array)
        return URI::encode(values.join(','))
      else
        return URI::encode(values.to_s)
      end    
    end
        
    # Coditions Clean-up by Dan
    # Example:
    # find(:all, :conditions => { :column_name => value, :column_name => { :operator => value } })
    
    def get_condition_string(conditions)
      queries = Array.new
      if conditions.is_a?(Hash)
        conditions.each_pair do |column, value|
          query = column.to_s.camelize
          if value.is_a?(Hash)
            query += "[_operator%3D#{value.keys.first.to_s}]=#{parse_value(value[value.keys.first])}"
          else
            query += "=#{parse_value(value)}"
          end
          queries << query
        end
        return queries.join('&')
      else
        raise ArgumentError, "Condition needs to be a hash of values, Please review the source code"
      end
    end
  end
end