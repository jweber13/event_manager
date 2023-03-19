require 'date'
require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
    check = phone_number.to_s.gsub(/\D/, '')
    case check.chars.count
    when 10
        check
    when 11
        if check[0] == 1
            return check.slice(1..10)
        else
            return " "
        end
    else
        return " "
    end
end

def legislators_by_zipcode(zip)
    civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
    civic_info.key = 'AIzaSyBvvZwQbA5IV6_QbobgQ6A_ZJlt5B7GiWg'

    begin
        civic_info.representative_info_by_address(
            address: zip,
            levels: 'country',
            roles: ['legislatorUpperBody', 'legislatorLowerBody']
          ).officials
    rescue
        'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
    end

end

def save_thank_you_letter(id, form_letter)
    #directory named “output” if a directory named “output” does not already exist.
    Dir.mkdir('output') unless Dir.exist?('output') 

    filename = "output/thanks_#{id}.html"

    File.open(filename, 'w') do |file| # w - want to open the file for writing
        file.puts form_letter #file inherits from IO#puts acts like Kernel#puts
    end
end

puts 'EventManager initialized.'

contents = CSV.open(
    'event_attendees.csv',
    headers: true,
    header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
    id = row[0]
    name = row[:first_name]

    zipcode = clean_zipcode(row[:zipcode])

    phone = clean_phone_number(row[:homephone])

    legislators = legislators_by_zipcode(zipcode)

    #instance of binding knows all about the current state of variables and methods within the given scope. 
    form_letter = erb_template.result(binding) 

    #puts "#{name} #{phone}"
    save_thank_you_letter(id, form_letter)
end
