require 'grape'
require 'pry'
require 'rest-client'
require 'logger'
require 'yaml'

class CompositeDecoder
  def self.decode(field)
    Hash[field
         .split("\n")
         .map { |x|
      match = x.scan(/(\w+?)\s=\s(.*$)/)[0]
      key = match[0]
      value = match[1]

      [key, value]
    }]
  end
end

class FormStack < Grape::API
  format :json
  resource :forms do

    post '/' do

      logger = Logger.new('post-log.log')

      ship_address = CompositeDecoder.decode params['Shipping Address:']
      doctor_address = CompositeDecoder.decode params['Physician Address:']
      lead_address = CompositeDecoder.decode params['Address:']

      lead_full_name = CompositeDecoder.decode(params['Name:'])
      doctor_name = CompositeDecoder.decode(params['Physician Name:'])


      form = {
          full_name: "#{lead_full_name['first']} #{lead_full_name['last']}",
          phone: params['Phone:'],
          insuranceName: params['Insurance Name:'],
          insurancePlanNumber: params['Insurance Plan Number:'],
          insuranceGroupNumber: params['Insurance Group Number:'],
          insuranceBinNumber: params['Insurance Bin Number:'],
          insurancePCNNumber: params['Insurance PCN Number: (if available on member card)'],
          address: lead_address['address'],
          address2: lead_address['address2'],
          city: lead_address['city'],
          stateCode: lead_address['state'],
          zipcode: lead_address['zip'],
          ship_to_address: ship_address['address'],
          ship_to_address2: ship_address['address2'],
          ship_to_city: ship_address['city'],
          ship_to_stateCode: ship_address['state'],
          ship_to_zipcode: ship_address['zip'],
          PhysicianNPI: params['Physician NPI:'],
          PhysicianFirstName: doctor_name['first'],
          PhysicianLastName: doctor_name['last'],
          PhysicianAddress1: doctor_address['address'],
          PhysicianAddress2: doctor_address['address2'],
          PhysicianCity: doctor_address['city'],
          PhysicianState: doctor_address['state'],
          PhysicianZip: doctor_address['zip'],
          PhysicianPhone: params['Physician Phone:'],
          PhysicianFax: params['Physician Fax:'],
      }

      matched_date = params['Date of Birth:'].scan(/(\d+)\/(\d+)\/(\d+)/)

      if matched_date.length > 0
        date_of_birth = "#{matched_date[0][2]}-#{matched_date[0]}-#{matched_date[1]}"
        form[:dateOfBirth] = date_of_birth
      end

      login_hash = {
          controller: 'leads',
          action: 'importOrders',
      }

      settings = YAML.load File.read(File.dirname(__FILE__) +'/../config.yml')

      center_code = params['Affiliate Callcenter']

      login_details = settings[:centers].select { |x| center_code.downcase.include?(x[:signature]) }.first

      login_hash[:email] = login_details[:login]
      login_hash[:password] = login_details[:password]

      response = RestClient.post 'http://api.insuracrm.com/api/', form.merge(login_hash)
      logger.info "Response of post: #{response.body}"

      'OK'
    end

  end

end