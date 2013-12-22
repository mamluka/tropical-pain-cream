require 'pdf_forms'

pdftk = PdfForms.new('/usr/bin/pdftk')

fields = pdftk.get_field_names 'pdf.pdf'

p fields

pdftk.fill_form 'pdf.pdf', 'pdf2.pdf', doctor_name: 'my doctor',doctor_address: 'this address',doctor_fax: '147852369',aspirin: 'Yes',payment_medical: 'Yes',patient_firstname: 'first name',patient_lastname: 'last name'