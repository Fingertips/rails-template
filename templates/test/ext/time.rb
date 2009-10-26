module TestHelpers
  module Time
    def freeze_time!(time = ::Time.parse('6/1/2009'))
      ::Time.stubs(:now).returns(time)
      time
    end
  end
end