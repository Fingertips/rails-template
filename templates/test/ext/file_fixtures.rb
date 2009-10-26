module TestHelpers
  module FileFixtures
    def fixture_file_upload(path, mime_type = nil, binary = false)
      fixture_path = ActionController::TestCase.send(:fixture_path) if ActionController::TestCase.respond_to?(:fixture_path)
      ActionController::TestUploadedFile.new("#{fixture_path}#{path}", mime_type, binary)
    end
  end
end