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
    conditions[:transaction_type_enum] ||= "Payment"
    url = "#{base_uri}/accounts/createtransaction/#{entry}"

    transaction_xml =
    "<?xml version='1.0' encoding='utf-16' ?>
    <Transaction>
      <TransactionTypeEnum>#{conditions[:transaction_type_enum]}</TransactionTypeEnum>
      <Amount>#{amount}</Amount>
      <Description>#{conditions[:description]}</Description>
      <TermSessionID>#{conditions[:term_session_id]}</TermSessionID>
      <ExternalID>#{conditions[:external_id]}</ExternalID>
      <Comments>#{conditions[:comments]}</Comments>
      <ChargeGroupID>#{conditions[:charge_group_id]}</ChargeGroupID>
      <ChargeItemID>#{conditions[:charge_item_id]}</ChargeItemID>
      <SecurityUserID>6</SecurityUserID>
    </Transaction>"

    response = post(url, :body => transaction_xml)
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
        doc.search("transactionid").inner_html
      else
        return false
      end
    end
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
        if charge_group[:tag].present?
          charge_groups_string += %(<TransactionTag>#{charge_group[:tag]}</TransactionTag>)
        end
        charge_groups_string += %(<TransactionExternalID>#{charge_group[:external_id]}</TransactionExternalID>) if charge_group[:external_id].present?
        charge_groups_string += %(<TransactionTermSessionID>#{charge_group[:term_session_id]}</TransactionTermSessionID>) if charge_group[:term_session_id].present?
        charge_groups_string += %(</BreakUp>)
      end
    else
      raise ArgumentError, "At least one charge group must be provided in :charge_groups"
    end

    amount_string = %(<Amount>#{amount}</Amount>)
    description_string = %(<Description>#{conditions[:description]}</Description>)

    payment_xml =
    "<?xml version='1.0' encoding='utf-16' ?>
    <Payment>
      <TransactionTypeEnum>Payment</TransactionTypeEnum>
      <PaymentTypeID>8</PaymentTypeID>
      <SecurityUserID>6</SecurityUserID>
      #{description_string}
      #{amount_string}
      #{charge_groups_string}
    </Payment>"

    response = post(url, body: payment_xml)
    if options[:return].eql? :response
      return response
    elsif options[:return].eql? :xml
      return payment_xml
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
