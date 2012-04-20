#!/usr/bin/ruby

# Based on http://pastebin.com/NBPyNKXf
require 'rubygems'
require 'net/https'
require 'json'
require 'csv'
require 'date'

module ExportIssues
  def ExportIssues.get_issues
    issue_pages = []
    # You should be able to make out total pages and per page values below
    # from the serial number of the last issue created on your github repo:
    total_pages = 1
    per_page = 100

    # Run the script - but make sure you stay below GitHub's (current, generous)
    # rate limit of 5000 requests per hour.

    1.upto(total_pages).each do |page|
      uri = URI.parse("https://api.github.com/repos/pwx/code/issues?page=#{page}&per_page=#{per_page}")
      http = Net::HTTP.new uri.host, uri.port
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.use_ssl = true

      http.start { |http|
        req = Net::HTTP::Get.new(uri.request_uri)
        req.basic_auth 'vamsee', 'v4m533K4NGH'
        response = http.request(req)
        issue_pages[page-1] = JSON.parse(response.body)
      }

      puts "#{issue_pages[page-1].size} issues retrieved in page #{page}"
    end

    issue_pages
  end

  def ExportIssues.get_username(name)
    unames = { 'vcolaco' => 'vinita', 'madanvk' => 'madan', 'mkristian' => 'kristian',
      'satyagrahi' => 'rajesh', 'ajaya' => 'ajaya', 'vamsee' => 'vamsee', 'thornedev' => 'larrie' }

    unames[name]
  end

  def ExportIssues.get_issue_comments(issue_id, total_comments)
    #Follow the recommended comment format for importing (http://goo.gl/xOh4k):
    #Tester Notes: MarkChai: 02/27/05 10:36:14 AM: Sufficiently tested attempting demos.
    comment_pages = []
    comments = []
    per_page = 25
    total_pages = total_comments/per_page
    total_pages += 1 if total_comments % per_page > 0

    1.upto(total_pages).each do |page|
      uri = URI.parse("https://api.github.com/repos/pwx/code/issues/#{issue_id}/comments?page=#{page}&per_page=#{per_page}")
      http = Net::HTTP.new uri.host, uri.port
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.use_ssl = true

      http.start { |http|
        req = Net::HTTP::Get.new(uri.request_uri)
        req.basic_auth 'vamsee', 'v4m533K4NGH'
        response = http.request(req)
        comment_pages[page-1] = JSON.parse(response.body)
      }
      
      puts "#{comment_pages[page-1].size} issues retrieved in page #{page}"
    end

    comment_pages.each do |cp|
      cp.each do |comment|
        username = get_username(comment['user']['login'])
        date = DateTime.parse(comment['created_at']).strftime("%m/%d/%y %I:%M:%S %p")
        
        comments << [comment['body'], username, date]
      end
    end

    comments
  end

  def ExportIssues.generate_csv(issue_pages)
    outfile = File.open('ghissues.csv', 'wb')
    max_comment_num = 0
    
    CSV::Writer.generate(outfile) do |csv|
      comment_cols = ['CommentBody'] * max_comment_num

      csv << ['Summary', 'Description', 'DateCreated', 'DateModified', 
              'Status', 'Reporter', 'Assignee', 'AffectsVersion'] + comment_cols

      issue_pages.each do |ip|
        ip.each do |issue|
          issue_id = issue['number']
          summary = issue['title']
          desc = issue['body']
          date_created = DateTime.parse(issue['created_at']).strftime("%m/%d/%y %I:%M:%S %p")
          date_updated = DateTime.parse(issue['updated_at']).strftime("%m/%d/%y %I:%M:%S %p")
          status = issue['state']
          reporter = get_username(issue['user']['login'])
          version = issue['milestone']['title']
          comments = issue['comments'] > 0 ? get_issue_comments(issue_id) : []
          
          csv << [summary, description, date_created, date_updated, 
                  status, reporter, version] + comments
        end
      end
    end
    
    outfile.close
  end
end
