module PunditHelper
  extend ActiveSupport::Concern

  included do
    def self.permissions(*methods, &block)
      methods.each do |method|
        describe "##{method}" do
          instance_eval(&block)
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include PunditHelper, type: :policy
  config.extend PunditHelper, type: :policy
end
