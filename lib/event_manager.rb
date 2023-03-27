require 'date'
require 'time'
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
    civic_info.key = 'YOUR KEY HERE'

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

class EventDateTime
    attr_accessor :times
    attr_accessor :days

    def initialize
        @times = []
        @days = []
    end

    def clean_date_time(d_t)
        begin
            #the date_time argument is in the format 11/12/08 10:47, which includes a date component. 
            #To parse a date and time string in the format 11/12/08 10:47, 
            # use the %m/%d/%y %H:%M format string.

            time = Time.strptime(d_t, "%m/%d/%y %H:%M")
            @times << time.hour
            @days << Date::DAYNAMES[time.wday]
        rescue ArgumentError => e
            puts "Error parsing date/time string: #{e.message}"
        end
    end
=begin
    def clean_date_time(d_t)
        @times << Time.strptime(d_t, "%m/%d/%y %H:%M").hour
        @days << Time.strptime(d_t, '%m/%d/%y %H:%M').wday
    end
=end

    public
    def get_peak_times
        hours = @times.sort
        max_consecutive_hours = []
        current_consecutive_hours = []

        hours.each_with_index do |h, i|
            #checks if the current hour h is one more than the previous hour in the hours list.
            #h == hours[i-1]+1 evaluates to 6 == hours[3]+1
            if i > 0 && h == hours[i-1]+1
                current_consecutive_hours << h
            else
                # If this hour is not consecutive with the previous hour, check if the current block is bigger than the previous maximum
                if current_consecutive_hours.length > max_consecutive_hours.length
                    max_consecutive_hours = current_consecutive_hours
                end
                #start a new block with this hour
                current_consecutive_hours[h]
            end
        end
        # If the current block is bigger than the previous maximum, update the maximum
        if current_consecutive_hours.length > max_consecutive_hours.length
            max_consecutive_hours = current_consecutive_hours
        end

        return max_consecutive_hours.join(", ")
    end

    public 
    def get_peak_days
        @days.reduce(Hash.new(0)) do |acc, curr| 
            acc[curr] += 1
            acc
        end.keys[0]
    end
end

date_time = EventDateTime.new
contents.each do |row|
    id = row[0]
    name = row[:first_name]

    zipcode = clean_zipcode(row[:zipcode])

    phone = clean_phone_number(row[:homephone])

    date_time.clean_date_time(row[:regdate])

    legislators = legislators_by_zipcode(zipcode)

    #instance of binding knows all about the current state of variables and methods within the given scope. 
    form_letter = erb_template.result(binding) 

    #puts "#{name} #{phone}"
    save_thank_you_letter(id, form_letter)
end

puts "The peak registration hours are: #{date_time.get_peak_times}"
puts "The peak registration day is #{date_time.get_peak_days}"

