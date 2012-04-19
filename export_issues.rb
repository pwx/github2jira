# Based on http://pastebin.com/NBPyNKXf
require 'rubygems'
require 'net/https'
require 'json'
require 'csv'

issues = nil
uri = URI.parse('https://api.github.com/repos/pwx/code/issues')
http = Net::HTTP.new uri.host, uri.port
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
http.use_ssl = true

http.start { |http|
  req = Net::HTTP::Get.new(uri.request_uri)
  req.basic_auth 'vamsee', 'v4m533K4NGH'
  response = http.request(req)
  issues = JSON.parse(response.body)
}

puts "Total issues: #{issues.size}"
outfile = File.open('ghissues.csv', 'wb')

CSV::Writer.generate(outfile) do |csv|
  issues.each do |issue|
    csv << [issue['number'], issue['title'], issue['labels'].sort.join(',')]
  end
end

outfile.close
