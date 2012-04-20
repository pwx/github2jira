#!/usr/bin/ruby

# Based on http://pastebin.com/NBPyNKXf
require 'rubygems'
require 'net/https'
require 'json'
require 'csv'
require 'date'

module ExportIssues
  def ExportIssues.get_issues(total_issues, per_page)
    issue_pages = []
    issues = []
    max_comments = 0
    
    total_pages = total_issues/per_page
    total_pages += 1 if total_issues % per_page > 0

    # pull the issues: make sure you stay below GitHub's (current, generous)
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

    issue_pages.each do |ip|
      ip.each do |issue|
        issue_id = issue['number']
        summary = issue['title']
        desc = issue['body']
        date_created = DateTime.parse(issue['created_at']).strftime("%d/%m/%Y %H:%M:%S")
        date_updated = DateTime.parse(issue['updated_at']).strftime("%d/%m/%Y %H:%M:%S")
        status = issue['state']
        reporter = get_username(issue['user']['login'])
        assignee = issue['assignee']['login'] if issue['assignee']
        version = issue['milestone']['title'] if issue['milestone']
        comments = issue['comments'] > 0 ? get_issue_comments(issue_id, issue['comments']) : []
        max_comments = comments.size if comments.size > max_comments
        
        issues << [summary, desc, date_created, date_updated, 
                   status, reporter, assignee, version] + comments
      end
    end

    generate_csv(issues, max_comments)
  end

  def ExportIssues.get_username(name)
    unames = { 'vcolaco' => 'vinita', 'madanvk' => 'madan', 'mkristian' => 'kristian',
      'satyagrahi' => 'rajesh', 'ajaya' => 'ajaya', 'vamsee' => 'vamsee', 'thornedev' => 'larrie' }

    unames[name]
  end

  def ExportIssues.get_issue_comments(issue_id, total_comments)
    #Follow the recommended comment format for importing (http://goo.gl/xOh4k):
    #Comment: MarkChai: 02/27/05 10:36:14 AM: Sufficiently tested attempting demos.
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
      
      puts "#{comment_pages[page-1].size} comments retrieved in page #{page}, issue #{issue_id}"
    end

    comment_pages.each do |cp|
      cp.each do |comment|
        username = get_username(comment['user']['login'])
        date = DateTime.parse(comment['created_at']).strftime("%m/%d/%y %I:%M:%S %p")        
        comments << ["Comment: #{username}: #{date}: #{comment['body']}"]
      end
    end

    comments
  end

  def ExportIssues.generate_csv(issues, max_comments)
    outfile = File.open('ghissues.csv', 'wb')
    
    CSV::Writer.generate(outfile) do |csv|
      comment_cols = ['CommentBody'] * max_comments
      csv << ['Summary', 'Description', 'DateCreated', 'DateModified',
              'Status', 'Reporter', 'Assignee', 'AffectsVersion'] + comment_cols
      issues.each do |issue|
        csv << issue
      end
    end
    
    outfile.close
  end
end
