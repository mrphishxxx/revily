module Revily::Event
  class Notifier
    autoload :Email,               "revily/event/notifier/sms"
    autoload :Phone,               "revily/event/notifier/sms"
    autoload :Sms,                 "revily/event/notifier/sms"

    attr_accessor :contact, :incidents

    class << self
      def notify(contact, incidents=[])
        new(contact, incidents).notify
      end
    end

    def initialize(contact, incidents=[])
      @contact = contact
      @incidents = incidents
    end

    def notify
      logger.warn "override Contact#notify in a subclass"
    end


    protected

    def address
      contact.address
    end

  end
end