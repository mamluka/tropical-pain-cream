require 'grape'
require 'pry'
require 'rest-client'
require 'logger'
require 'yaml'
require 'json'
require 'google_drive'

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

      logger.info JSON.pretty_generate(params)

      ship_address = CompositeDecoder.decode [params['When we ship the cream to you, someone will have to sign for the package, being that it is a medication. It will be shipped during normal business hours of 8am -5pm. Where would you like to have it shipped to? (Home, Work, etc…., ask if there is A Unit #)'],
                                              params['Prospects Address'],
                                              params['Please provide me your Physical Address '],
                                              params['Shipping Address'],
                                              params['Where would you like to have it shipped to? '],
                                              params['Where would you like to have it shipped to?'],
                                              params['What is your address?'],
                                              params['When we ship the cream to you, someone will have to sign for the package, being that it is a medication. It will be shipped during normal business hours of 8am -5pm. What is your physical address?']
                                             ].compact.select { |x| x.length > 0 }.first


      lead_name_field = ([params['Name'], params['Now just to confirm, I have your Name spelled as (Confirm First/Last Name)'], params['What is your name as it appears on the card?']].compact.first)

      if lead_name_field.include? "\n"
        lead_full_name = CompositeDecoder.decode lead_name_field
      else
        lead_full_name = {
            first: lead_name_field.split(' ').first,
            last: (lead_name_field.split(' ').last rescue "Not set")
        }
      end
      form = {
          full_name: "#{lead_full_name['first']} #{lead_full_name['last']}",
          phone: [params['Primary Phone #'], params['Phone'], params['What is the best number to reach you?'], params['Do you know the phone number for that office?'],params['What is your primary phone number?']].compact.first,
          insuranceCarrierName: [params['What is the name of your Health insurance carrier?'], params['Insurance Company Name'], params['What is the name of your Insurance Company Name?']].compact.first,
          insuranceCarrierPhone: [params['What’s the Phone Number of your Insurance Company?'], params['Insurance Company Phone #'], params['What is your Insurance Company\'s Phone #?']].compact.first,
          insurancePlanNumber: [params['On the front of the card you should see your Policy Number or Member ID Number. What is that number? '], params['Insurance Company Member ID/Policy #'], params['What is your Insurance Company\'s Member ID/Policy #']].compact.first,
          insuranceGroupNumber: [params['What is the RX Group # Number? '], params['Insurance RX Group #'], params['Your RX Group # ?'],params['What is the RX Group # Number?']].compact.first,
          insuranceBinNumber: [params['What is the RX BIN # Number?'], params['Insurance RX BIN #'], params['Your Insurance RX BIN # ?']].compact.first,
          insurancePCNNumber: [params['What is the PCN Number?'], params['Insurance PCN Number'], params['What is your PCN Number ?']].compact.first,
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

      doctor_name = [params['Doctors Name'], params['Ok. Great!! What’s the name of the Doctor you’re seeing for your pain?'], params['What’s the name of the Doctor you’re seeing for your pain?'],params['What is your name as it appears on the card?']].compact.first
      if doctor_name.include? "\n"
        form = form.merge PhysicianFirstName: doctor_name['first'],
                          PhysicianLastName: doctor_name['last']
      else
        form = form.merge PhysicianFirstName: doctor_name[0], PhysicianLastName: (doctor_name[1] rescue 'Not given')
      end

      dob_param = [params['What is your DOB? (Must be 64yrs old and younger)'], params['What is your DOB? (Must be 64yrs old and younger)'], params['Date Of Birth'], params['What is your date of birth?'], params['What is your DOB?'], params['What is your DOB? '], params['What is your Date Of Birth?']].compact.first
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

      session = GoogleDrive.login($settings[:google][:username], $settings[:google][:password])
      ws = session.spreadsheet_by_key($settings[:google][:doc_id]).worksheets[0]

      new_row_num = ws.rows.length + 1

      ws[new_row_num, 1] = Time.now.to_s
      ws[new_row_num, 2] = form[:dateOfBirth]
      ws[new_row_num, 3] = form[:full_name]

      ws[new_row_num, 4] = form[:phone]

      ws[new_row_num, 5] = form[:insuranceCarrierName]

      ws[new_row_num, 6] = form[:insuranceCarrierPhone]
      ws[new_row_num, 7] = form[:insuranceName]
      ws[new_row_num, 8] = form[:insurancePlanNumber]
      ws[new_row_num, 9] = form[:insuranceGroupNumber]
      ws[new_row_num, 10] = form[:insuranceBinNumber]
      ws[new_row_num, 11] = form[:insurancePCNNumber]
      ws[new_row_num, 12] = form[:address]
      ws[new_row_num, 13] = form[:city]
      ws[new_row_num, 14] = form[:stateCode]
      ws[new_row_num, 15] = form[:zipcode]
      ws[new_row_num, 16] = form[:ship_to_address]
      ws[new_row_num, 17] = form[:ship_to_city]
      ws[new_row_num, 18] = form[:ship_to_stateCode]
      ws[new_row_num, 19] = form[:PhysicianNPI]
      ws[new_row_num, 20] = form[:PhysicianFirstName]
      ws[new_row_num, 21] = form[:PhysicianLastName]
      ws[new_row_num, 22] = form[:PhysicianAddress1]
      ws[new_row_num, 23] = form[:PhysicianCity]
      ws[new_row_num, 24] = form[:PhysicianState]
      ws[new_row_num, 25] = form[:PhysicianZip]
      ws[new_row_num, 26] = form[:PhysicianPhone]
      ws[new_row_num, 27] = form[:PhysicianFax]

      ws.save

      response = RestClient.post "https://#{subdomain}.insuracrm.com/api/", form.merge(login_hash)

      logger.info 'Submitted'
      logger.info JSON.pretty_generate(form)
      logger.info "Response of post: #{response.body}"

      'OK'
    end
  end
end
