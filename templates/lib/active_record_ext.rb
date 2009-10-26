module ActiveRecord
  module Ext
    # Loads various parts of a class definition, a simple way to separate large classes.
    #
    #   class Member
    #     embrace :authentication
    #   end
    def embrace(*parts)
      parts.each do |part|
        require_dependency "#{name.downcase}/#{part}"
      end
    end
  end
  
  module BasicScopes
    def self.included(base)
      base.named_scope(:order, Proc.new do |attribute, direction|
        order = "#{attribute}"
        order << " #{direction.to_s.upcase}" unless direction.blank?
        { :order => order }
      end)
      
      base.named_scope :limit, Proc.new { |limit| { :limit => limit } }
    end
  end
end