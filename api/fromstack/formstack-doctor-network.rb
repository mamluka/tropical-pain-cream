require 'grape'
require 'pry'
require 'rest-client'
require 'logger'
require 'yaml'
require 'json'

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

class CheckboxListDecoder
  def self.checked?(field, value)
    field.downcase.include?(value.downcase) ? 'Yes' : nil
  end
end

class FormStackDoctorNetwork < Grape::API
  format :json
  resource :forms do
    post '/doctor-network' do

      logger = Logger.new('biotech-post-log.log')

      logger.info "Form"
      logger.info JSON.pretty_generate(params)

      ship_address = CompositeDecoder.decode [params['When we ship the cream to you, someone will have to sign for the package, being that it is a medication. It will be shipped during normal business hours of 8am -5pm. Where would you like to have it shipped to? (Home, Work, etc…., ask if there is A Unit #)'],
                                              params['Prospects Address'],
                                              params['Shipping Address']].compact.select { |x| !x.empty? }.first


      lead_full_name = CompositeDecoder.decode(params['Name'])

      form = {
          full_name: "#{lead_full_name['first']} #{lead_full_name['last']}",
          phone: [params['Primary Phone #'], params['Phone']].compact.first,
          insuranceCarrierName: [params['What is the name of your Health insurance carrier?'], params['Insurance Company Name']].compact.first,
          insurancePlanNumber: [params['On the front of the card you should see your Policy Number or Member ID Number. What is that number? '], params['Insurance Company Member ID/Policy #']].compact.first,
          insuranceGroupNumber: [params['What is the RX Group # Number? '], params['Insurance RX Group #']].compact.first,
          insuranceBinNumber: [params['What is the RX BIN # Number?'], params['Insurance RX BIN #']].compact.first,
          insurancePCNNumber: [params['What is the PCN Number?'], params['Insurance PCN Number']].compact.first,
          address: 'unspecified',
          address2: 'unspecified',
          city: 'unspecified',
          stateCode: 'NY',
          zipcode: '12345',
          ship_to_address: ship_address['address'],
          ship_to_address2: ship_address['address2'],
          ship_to_city: ship_address['city'],
          ship_to_stateCode: ship_address['state'],
          ship_to_zipcode: ship_address['zip'],
          PhysicianNPI: 'unspecified',
          PhysicianAddress1: 'unspecified',
          PhysicianAddress2: 'unspecified',
          PhysicianCity: 'unspecified',
          PhysicianState: 'NY',
          PhysicianZip: '12345',
          PhysicianPhone: [params['Do you know the phone number?'], params['Do you know the phone number'], params['Doctors Phone #']].compact.first,
          PhysicianFax: '9876111111',
      }

      if params['Doctors Name']
        doctor_name = CompositeDecoder.decode(params['Doctors Name'])
        form = form.merge PhysicianFirstName: doctor_name['first'],
                          PhysicianLastName: doctor_name['last']

      else
        doctor_name = params['Ok. Great!! What’s the name of the Doctor you’re seeing for your pain?'].split(' ')
        form = form.merge PhysicianFirstName: doctor_name[0], PhysicianLastName: (doctor_name[1] rescue 'Not given')
      end

      dob_param = [params['What is your DOB? (Must be 64yrs old and younger)'], params['What is your DOB? (Must be 64yrs old and younger)'], params['Date Of Birth'], params['What is your DOB?']].compact.first
      matched_date = dob_param.scan(/(\d+)\/(\d+)\/(\d+)/)

      if matched_date.length > 0
        date_of_birth = "#{matched_date[0][2]}-#{matched_date[0][0]}-#{matched_date[0][1]}"
        form[:dateOfBirth] = date_of_birth
      end

      login_hash = {
          controller: 'leads',
          action: 'importOrders',
      }

      center_code = params['code']

      login_details = $settings[:centers].select { |x| center_code.downcase == x[:signature].to_s.downcase }.first

      login_hash[:email] = login_details[:login]
      login_hash[:password] = login_details[:password]
      subdomain = login_details[:subdomain]

      response = RestClient.post "https://#{subdomain}.insuracrm.com/api/", form.merge(login_hash)

      logger.info 'Submitted'
      logger.info JSON.pretty_generate(form)
      logger.info "Response of post: #{response.body}"

      'OK'
    end
  end
end
