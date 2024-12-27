require 'fastlane/action'
require_relative '../helper/jira_issue_features_helper'
require 'net/http'
require 'json'
require 'base64'

module Fastlane
  module Actions
    class JiraIssueFeaturesAction < Action
      def self.run(params)
        jira_base_url = params[:jira_base_url]
        issue_id = params[:issue_id]
        target_column_name = params[:target_column_name]
        email = params[:email]
        api_token = params[:api_token]
        comment = params[:comment]
        # Step 1: Transition List Retrieval
        UI.message("Fetching available transitions for issue '#{issue_id}'...")
        transitions = fetch_transitions(jira_base_url, issue_id, email, api_token)

        # Step 2: Find Transition ID for Target Column
        transition_id = find_transition_id(transitions, target_column_name)

        if transition_id.nil?
          UI.error("Target column '#{target_column_name}' not found in transitions for issue '#{issue_id}'.")
          return
        end

        UI.message("Found transition ID '#{transition_id}' for column '#{target_column_name}'.")

        # Step 3: Execute Transition
        UI.message("Moving issue '#{issue_id}' to column '#{target_column_name}'...")
        execute_transition(jira_base_url, issue_id, transition_id, email, api_token)
        if params[:comment].to_s.strip.empty?
          UI.important("No comment provided. Skipping comment addition for issue '#{params[:issue_id]}'.")
        else
          UI.message("Adding comment to issue '#{params[:issue_id]}'...")
          add_comment_to_issue(jira_base_url, issue_id, comment, email, api_token)
        end
        UI.success("Issue '#{issue_id}' successfully moved to '#{target_column_name}'!")
      end

      # Fetch available transitions for the issue
      def self.fetch_transitions(base_url, issue_id, email, api_token)
        uri = URI("#{base_url}/rest/api/3/issue/#{issue_id}/transitions")
        response = make_request(uri, email, api_token, :get)
        return JSON.parse(response.body)['transitions'] if response.is_a?(Net::HTTPSuccess)

        UI.error("Failed to fetch transitions: #{response.body}")
        exit
      end

      # Add a comment to the specified JIRA issue
      def self.add_comment_to_issue(base_url, issue_id, comment, email, api_token)
        uri = URI("#{base_url}/rest/api/3/issue/#{issue_id}/comment")
        body = {
          "body" => {
            "content" => [
              {
                "content" => [
                  {
                    "text" => comment,
                    "type" => "text",
                    "marks": [
                      {
                        "type": "textColor",
                        "attrs": {
                          "color": "#FF0000"
                        }
                      },
                      {
                        "type": "strong"
                      },
                      {
                        "type": "underline"
                      }
                    ]
                    
                  }
                ],
                "type" => "paragraph"
              }
            ],
            "type" => "doc",
            "version" => 1
          }
        }.to_json
        response = make_request(uri, email, api_token, :post, body)
      
        if response.is_a?(Net::HTTPSuccess)
          UI.success("Comment added to issue '#{issue_id}': #{comment}")
        else
          UI.error("Failed to add comment to issue '#{issue_id}': #{response.body}")
          exit
        end
      end

      # Find the transition ID for the target column
      def self.find_transition_id(transitions, column_name)
        transitions.find { |t| t['name'].casecmp(column_name).zero? }&.dig('id')
      end

      # Execute the transition for the issue
      def self.execute_transition(base_url, issue_id, transition_id, email, api_token)
        uri = URI("#{base_url}/rest/api/3/issue/#{issue_id}/transitions")
        body = { transition: { id: transition_id } }.to_json
        response = make_request(uri, email, api_token, :post, body)

        unless response.is_a?(Net::HTTPSuccess)
          UI.error("Failed to move issue: #{response.body}")
          exit
        end
      end

      # Make HTTP request with proper headers
      def self.make_request(uri, email, api_token, method, body = nil)
        request = method == :get ? Net::HTTP::Get.new(uri) : Net::HTTP::Post.new(uri)
        request['Authorization'] = "Basic #{Base64.strict_encode64("#{email}:#{api_token}")}"
        request['Content-Type'] = 'application/json'
        request.body = body if body

        Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.request(request)
        end
      end

      def self.description
        "Automates Jira's features."
      end

      def self.authors
        ["Bilal Durnagol"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "Changing columns, adding comments, reading title, etc..."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :jira_base_url,
                                       description: "Base URL of your JIRA instance (e.g., https://your-domain.atlassian.net)",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :issue_id,
                                       description: "The JIRA issue ID (e.g., IOS-405)",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :target_column_name,
                                       description: "The target column name (e.g., REVIEW)",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :email,
                                       description: "Your JIRA account email",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :api_token,
                                       description: "Your JIRA API token",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :comment,
                                       description: "Comment to add to the JIRA issue (optional)",
                                       optional: true,
                                       type: String)                             
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        # [:ios, :mac, :android].include?(platform)
        true
      end
    end
  end
end
