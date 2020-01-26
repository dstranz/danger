# coding: utf-8

module Danger
  module RequestSources
    class CodeInsightsAPI
      attr_accessor :report_title, :report_description, :logo_url, :username, :password, :host

      def initialize(project, slug, environment)
        @report_title = environment["DANGER_BITBUCKETSERVER_CODE_INSIGHTS_REPORT_TITLE"]
        @report_key = environment["DANGER_BITBUCKETSERVER_CODE_INSIGHTS_REPORT_KEY"]
        @report_description = environment["DANGER_BITBUCKETSERVER_CODE_INSIGHTS_REPORT_DESCRIPTION"]
        @logo_url = environment["DANGER_BITBUCKETSERVER_CODE_INSIGHTS_REPORT_LOGO_URL"]
        @username = environment["DANGER_BITBUCKETSERVER_USERNAME"]
        @password = environment["DANGER_BITBUCKETSERVER_PASSWORD"]
        @host = environment["DANGER_BITBUCKETSERVER_HOST"]
        @project = project
        @slug = slug
      end

      def is_ready
        !(@report_title.empty? || @report_description.empty? || @logo_url.empty? || @username.empty? || @password.empty? || @host.empty?)
      end

      def delete_report(commit)
        endpoint_uri = URI(endpoint_per_commit(commit))
        req = Net::HTTP::Delete.new(endpoint_uri.request_uri, { "Content-Type" => "application/json" })
        req.basic_auth @username, @password
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl) do |http|
          http.request(req)
        end
      end

      def post_report(commit)
        uri = URI(report_endpoint_at_commit(commit))
        body = "omfg"
        post(uri, body)
      end

      def post_annotations(commit, inline_warnings, inline_errors, inline_messages)
        uri = URI(annotation_endpoint_at_commit(commit))
        annotations = []

        inline_messages.each do |violation|
          annotation = {}
          annotation["message"] = violation.message.to_s
          annotation["severity"] = "LOW"
          annotation["path"] = violation.file.to_s
          annotation["line"] = violation.line.to_i
          annotations << annotation
        end

        inline_warnings.each do |violation|
          annotation = {}
          annotation["message"] = violation.message.to_s
          annotation["severity"] = "MEDIUM"
          annotation["path"] = violation.file.to_s
          annotation["line"] = violation.line.to_i
          annotations << annotation
        end

        inline_errors.each do |violation|
          annotation = {}
          annotation["message"] = violation.message.to_s
          annotation["severity"] = "HIGH"
          annotation["path"] = violation.file.to_s
          annotation["line"] = violation.line.to_i
          annotations << annotation
        end

        body = { "annotations" => annotations }.to_json
        post(uri, body)
      end
    end

    def report_endpoint_at_commit(commit)
      "#{@host}/rest/insights/1.0/projects/#{@project}/repos/#{@slug}/commits/#{commit}/reports/#{@report_title}"
    end

    def annotation_endpoint_at_commit(commit)
      report_endpoint_at_commit(commit) + "/annotations"
    end

    def post(uri, body)
      request = Net::HTTP::Post.new(uri.request_uri, { "Content-Type" => "application/json" })
      request.basic_auth @username, @password
      request.body = body

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl) do |http|
        http.request(request)
      end

      # show failure when server returns an error
      case response
      when Net::HTTPClientError, Net::HTTPServerError
        # HTTP 4xx - 5xx
        abort "\nError posting comment to Code Insights API: #{response.code} (#{response.message}) - #{response.body}\n\n"
      end
    end

    def use_ssl
      @host.include? "https://"
    end
  end
end
