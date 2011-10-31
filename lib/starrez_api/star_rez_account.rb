require 'httparty'
require 'xmlsimple'


class StarRezAccount
  include HTTParty
  base_uri STARREZ_CONFIG['base_uri']
  headers 'StarRezUsername' => STARREZ_CONFIG['username'], 'StarRezPassword' => STARREZ_CONFIG['password']
  
  attr_accessor :name, :results, :total_amount, :total_tax_amount, :total_tax_amount2, :entry_id
  
  def self.get_balance(*args)
    options = args.extract_options!
    entry = args[0] || @entry_id
    charge_group = args[1] || options[:charge_group]
    if entry.blank?
      raise IOError, "Must include an Entry ID to search"
    end
    url = "#{base_uri}/accounts/getbalance/#{entry}/#{charge_group}"
    response = get(url)
    if options[:return].eql? :response
      return response
    else
      if response.code.eql? 404
        raise ArgumentError, "Invalid Entry ID"
      elsif response.code.eql? 403
        raise SecurityError, 'Access Denied to API'
      elsif response.code.eql? 200
        doc = Hpricot(response)
        account = StarRezAccount.new
        account.name = doc.at("Entry").at("title").inner_html
        account.total_amount = "%.2f" % doc.at("totalamount").inner_html
        account.total_tax_amount = "%.2f" % doc.at("totaltaxamount").inner_html
        account.total_tax_amount2 = "%.2f" % doc.at("totaltaxamount2").inner_html
        account
      else
        return false
      end
    end
  end
  
  def self.create_transaction(entry,amount,conditions={},options={})
    # TODO: Get this working at some point, create_payment is good enough for now.
  end
  
  def self.create_payment(entry,amount,conditions={},options={})
    conditions[:description] ||= "Deposit"
    url = "#{base_uri}/accounts/createpayment/#{entry}"
    charge_groups_string = ""
    if conditions[:charge_groups].any?
      break_up_total = conditions[:charge_groups].collect { |g| g[:amount] }.reduce(&:+)
      raise ArgumentError, "Payment amount and charge group breakup amounts must be equal" unless break_up_total == amount
      conditions[:charge_groups].each do |charge_group|
        if charge_group[:id].present?
          charge_groups_string += %(<BreakUp ChargeGroupID="#{charge_group[:id]}">)
        elsif charge_group[:name].present?
          charge_groups_string += %(<BreakUp ChargeGroup="#{charge_group[:name]}">)
        else
          raise ArgumentError, "Charge group ID or name must be provided"
        end
        raise ArgumentError, "Amount must be provided for payment breakup" if charge_group[:amount].blank?
        charge_groups_string += %(<Amount>#{charge_group[:amount]}</Amount>)
        if charge_group[:comments].present?
          charge_groups_string += %(<TransactionComments>#{charge_group[:comments]}</TransactionComments>)
        end
        if charge_group[:tag].present?
          charge_groups_string += %(<TransactionTag>#{charge_group[:tag]}</TransactionTag>)
        end
        charge_groups_string += %(<TransactionExternalID>#{charge_group[:external_id]}</TransactionExternalID>) if charge_group[:external_id].present?
        charge_groups_string += %(</BreakUp>)
      end
    else
      raise ArgumentError, "At least one charge group must be provided in :charge_groups"
    end
    
    payment_xml = <<XML  
    <Payment>
      <TransactionTypeEnum>Payment</TransactionTypeEnum>
      <PaymentTypeID>8</PaymentTypeID>
      <Description>#{conditions[:description]}</Description>
      <Amount>#{amount}</Amount>
      #{charge_groups_string}
    </Payment>
XML
    
    response = post(url, :body => payment_xml)
    if options[:return].eql? :response
      return response
    else
      if response.code.eql? 409
        raise ArgumentError, "Duplicate Transaction Found"
      elsif response.code.eql? 404
        raise ArgumentError, "Invalid Entry ID"
      elsif response.code.eql? 403
        raise SecurityError, 'Access Denied to API'
      elsif response.code.eql? 400
        raise ArgumentError, "Bad Request"
      elsif response.code.eql? 200
        doc = Hpricot(response.body)
        doc.search("paymentid").inner_html
      else
        return false
      end
    end
  end
  
  private
    
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