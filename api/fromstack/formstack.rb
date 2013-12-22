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

class CheckboxListDecoder
  def self.checked?(field, value)
    field.downcase.include?(value.downcase) ? 'Yes' : nil
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

      center_code = params['Affiliate Callcenter']

      login_details = $settings[:centers].select { |x| center_code.downcase.include?(x[:signature]) }.first

      login_hash[:email] = login_details[:login]
      login_hash[:password] = login_details[:password]

      response = RestClient.post 'http://api.insuracrm.com/api/', form.merge(login_hash)
      logger.info "Response of post: #{response.body}"

      'OK'
    end

    post '/to-pdf' do

      logger = Logger.new('to-pdf-.log')

      doctor_name = CompositeDecoder.decode(params['Doctor'])
      patient_name = CompositeDecoder.decode(params['Patient Name'])
      doctor_address= CompositeDecoder.decode params['Doctor Address']
      patient_address= CompositeDecoder.decode params['Patient Address']

      doctor_name = "#{doctor_name['first']} #{doctor_name['last']}"
      form = {
          doctor_name: doctor_name,
          doctor_address: doctor_address['address'],
          doctor_phone: params['Doctor Phone'],
          doctor_fax: params['Doctor Fax'],
          dea: params['DEA #'],
          npi: params['NPI #'],
          doctor_city_state_zip: "#{doctor_address['city']} #{doctor_address['state']} #{doctor_address['zip']}",
          patient_lastname: patient_name['last'],
          patient_middle: patient_name['middle'],
          patient_city: patient_address['city'],
          patient_state: patient_address['state'],
          patient_firstname: patient_name['first'],
          patient_zip: patient_address['zip'],
          patient_address: patient_address['address'],
          patient_phone: params['Patient Phone'],
          patient_alt_phone: params['Patient Alt Phone'],
          patient_dob: params['Patient Date of Birth'],
          patient_ss: params['Last 4-digits of SS#'],
          diagnosis: params['Diagnosis'],
          icd: params['ICD-9 Codes'],
          aspirin: CheckboxListDecoder.checked?(params['Allergies'], 'Aspirin'),
          codeine: CheckboxListDecoder.checked?(params['Allergies'], 'Codeine'),
          macrolides: CheckboxListDecoder.checked?(params['Allergies'], 'Macrolides'),
          penicillin: CheckboxListDecoder.checked?(params['Allergies'], 'Penicillin'),
          quinolone: CheckboxListDecoder.checked?(params['Allergies'], 'Quinolone'),
          cephalosporin: CheckboxListDecoder.checked?(params['Allergies'], 'Cephalosporin'),
          sulfa: CheckboxListDecoder.checked?(params['Allergies'], 'Sulfa'),
          tetracycline: CheckboxListDecoder.checked?(params['Allergies'], 'Tetracycline'),
          allergies_other: params['Allergies Other:'],
          carrier: params['Carrier Name'],
          member_id: params['Member ID #'],
          rx_group: params['Member ID #'],
          rx_bin: params['Rx Bin #'],
          pcn: params['PCN #'],
          carrier_phone: params['Carrier Phone #'],
          payment_medicare: params['Payment Type'].include?('Medicare + Supplemental Insurance') ? 'Yes' : nil,
          payment_comp: params['Payment Type'].include?('Worker’s Comp') ? 'Yes' : nil,
          payment_cash: params['Payment Type'].include?('Cash') ? 'Yes' : nil,
          payment_third_party: params['Payment Type'].include?('Third Party Insurance') ? 'Yes' : nil,
          payment_hmo: params['Payment Type'].include?('HMO/PPO') ? 'Yes' : nil,
          payment_pip: params['Payment Type'].include?('Personal Injury/Auto/PIP') ? 'Yes' : nil,
      }

      require 'pdf_forms'
      require 'dropbox_sdk'

      pdftk = PdfForms.new('/usr/bin/pdftk')

      pdf_filename = "Patient-#{patient_name['first']}-#{patient_name['last']}-#{Date.today.strftime('%d-%m-%Y')}-#{SecureRandom.uuid[0..4]}.pdf"

      pdf_filename_full_path = "#{File.dirname(__FILE__)}/saved-forms/#{pdf_filename}"

      template_pdf = File.dirname(__FILE__) +'/template.pdf'

      pdftk.fill_form template_pdf, pdf_filename_full_path, form

      client = DropboxClient.new($settings[:dropbox_key])
      client.put_file("#{$settings[:dropbox_folder]}/#{pdf_filename}", open(pdf_filename_full_path))

      'OK'
    end

  end

end