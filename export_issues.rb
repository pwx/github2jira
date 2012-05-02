#!/usr/bin/ruby

# Based on http://pastebin.com/NBPyNKXf
require 'rubygems'
require 'net/https'
require 'json'
require 'fastercsv'
require 'date'

# add the issues that are causing problems with import
# we can fix these later
SKIP_LIST = [639, 542, 234, 235]

module ExportIssues
  def ExportIssues.get_all_issues(issue_start, issue_end)
    issues = []
    issues_n_comments = []
    max_comments = 0
    
    # pull the issues: make sure you stay below GitHub's (current, generous)
    # rate limit of 5000 requests per hour.

    issue_start.upto(issue_end).each_with_index do |inum, idx|
      uri = URI.parse("https://api.github.com/repos/pwx/code/issues/#{inum}")
      http = Net::HTTP.new uri.host, uri.port
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.use_ssl = true
      
      http.start { |http|
        req = Net::HTTP::Get.new(uri.request_uri)
        req.basic_auth 'vamsee', 'v4m533K4NGH'
        response = http.request(req)
        issues[idx] = JSON.parse(response.body)
      }
      
      puts "Retrieved issue #{inum}"
    end

    puts "Retrieving comments for issues"

    issues.each do |issue|
      issue_id = issue['number']
      comments = []
      summary = issue['title']
      reporter = get_username(issue['user']['login'])
      desc = issue['body'] || 'No description given'

      if SKIP_LIST.include?(issue_id)
        # issue is giving problems either in description or in comments,
        # so setup only title and do the rest manually (including comments):
        desc = "Skipped migration due to csv probs. Please refer https://github.com/pwx/code/issues/#{issue_id}"
      end

      if desc.match(/\*\*Author:\s.+\*\*/)
        uname = get_username(desc.match(/\*\*Author:\s(.+)\*\*/)[1])
        if uname
          reporter = uname
          desc = desc.gsub(/\*\*Author:\s.+\*\*/,'')
        end
      end

      date_created = DateTime.parse(issue['created_at']).strftime("%d/%m/%Y %H:%M:%S")
      date_updated = DateTime.parse(issue['updated_at']).strftime("%d/%m/%Y %H:%M:%S")
      status = issue['state'].capitalize
      resolution = status == 'Open' ? 'Unresolved' : 'Fixed'
      assignee = get_username(issue['assignee']['login']) if issue['assignee']
      version = issue['milestone']['title'] if issue['milestone']

      if issue['comments'] > 0 && !SKIP_LIST.include?(issue_id)
        comments = get_issue_comments(issue_id, issue['comments'])
        max_comments = comments.size if comments.size > max_comments
      else
        puts "0 comments retrieved in issue #{issue_id}"
      end
        
      issues_n_comments << [summary, desc, date_created, date_updated, status, reporter, assignee, version, resolution] + comments
    end

    generate_csv(issues_n_comments, max_comments)
  end

  def ExportIssues.get_issues(total_issues, per_page=100)
    issue_pages = []
    issues = []
    max_comments = 0
    
    total_pages = total_issues/per_page
    total_pages += 1 if total_issues % per_page > 0

    # pull the issues: make sure you stay below GitHub's (current, generous)
    # rate limit of 5000 requests per hour.

    1.upto(total_pages).each do |page|
      uri = URI.parse("https://api.github.com/repos/pwx/code/issues?state=closed&page=#{page}&per_page=#{per_page}")
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
        next if SKIP_LIST.include?(issue_id)
        comments = []
        summary = issue['title']
        reporter = get_username(issue['user']['login'])
        desc = issue['body']

        if desc.match(/\*\*Author:\s.+\*\*/)
          uname = get_username(desc.match(/\*\*Author:\s(.+)\*\*/)[1])
          reporter = uname if uname
          desc = desc.gsub(/\*\*Author:\s.+\*\*/,'')
        end

        date_created = DateTime.parse(issue['created_at']).strftime("%d/%m/%Y %H:%M:%S")
        date_updated = DateTime.parse(issue['updated_at']).strftime("%d/%m/%Y %H:%M:%S")
        status = issue['state']
        assignee = get_username(issue['assignee']['login']) if issue['assignee']
        version = issue['milestone']['title'] if issue['milestone']

        if issue['comments'] > 0          
          comments = get_issue_comments(issue_id, issue['comments'])
          max_comments = comments.size if comments.size > max_comments
        else
          puts "0 comments retrieved in issue #{issue_id}"
        end
        
        issues << [summary, desc, date_created, date_updated, 
                   status, reporter, assignee, version] + comments
      end
    end

    generate_csv(issues.reverse, max_comments)
  end

  def ExportIssues.get_username(name)
    unames = { 'vcolaco' => 'vinita', 'madanvk' => 'madan', 'mkristian' => 'kristian', 'satyagrahi' => 'rajesh', 'ajaya' => 'ajaya', 'vamsee' => 'vamsee', 'thornedev' => 'larrie', 'ajay' => 'ajaya' }

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
      
      puts "#{comment_pages[page-1].size} comments retrieved in issue #{issue_id}"
    end

    comment_pages.each do |cp|
      cp.each do |comment|
        username = get_username(comment['user']['login'])
        date = DateTime.parse(comment['created_at']).strftime("%d/%m/%y %H:%M:%S")
        desc = comment['body']
        
        if desc.match(/\*\*Author:\s.+\*\*/)
          uname = get_username(desc.match(/\*\*Author:\s(.+)\*\*/)[1])
          username = uname if uname
          desc = desc.gsub(/\*\*Author:\s.+\*\*/,'')
        end
        
        comments << ["#{date}; #{username}; #{desc}"]
      end
    end

    comments
  end

  def ExportIssues.generate_csv(issues, max_comments)
    FasterCSV.open('ghissues.csv', 'w') do |csv|   
      comment_cols = ['CommentBody'] * max_comments
      csv << ['Summary', 'Description', 'DateCreated', 'DateModified', 'Status', 'Reporter', 'Assignee', 'AffectsVersion', 'Resolution'] + comment_cols
      issues.each do |issue|
        csv << issue
      end
    end
  end
end
