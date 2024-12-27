describe Fastlane::Actions::JiraIssueFeaturesAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The jira_issue_features plugin is working!")

      Fastlane::Actions::JiraIssueFeaturesAction.run(nil)
    end
  end
end
