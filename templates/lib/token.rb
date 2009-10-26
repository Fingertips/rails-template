module Token
  DEFAULT_LENGTH = 8
  
  def self.generate(requested_length=DEFAULT_LENGTH)
    length = requested_length.odd? ? requested_length + 1 : requested_length
    token = (1..length/2).map { |i| (1..2).map { (i.odd? ? ('a'..'z') : ('0'..'9')).to_a.rand }.join }.join
    token[0...requested_length]
  end
end