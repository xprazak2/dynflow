module Dynflow
  # TODO use actress when released, copied over from actress gem https://github.com/pitr-ch/actress
  class MicroActor
    include Algebrick::TypeCheck
    include Algebrick::Matching

    attr_reader :logger

    Terminate = Algebrick.atom

    def initialize(logger, *args)
      @logger = logger
      @thread = Thread.new do
        Thread.current.abort_on_exception = true
        @mailbox                          = Queue.new
        @stop                             = false
        @stopped                          = Future.new
        delayed_initialize(*args)
        @initialized
        catch(Terminate) { loop { receive } }
        @stopped.resolve true
      end
      Thread.pass while @stopped.nil?
    end

    def <<(message)
      @mailbox << message
      self
    end

    def terminate!
      raise if Thread.current == @thread
      @mailbox << Terminate
      @stopped.wait
    end

    private

    def delayed_initialize(*args)
    end

    def on_message(message)
      raise NotImplementedError
    end

    def receive
      message = @mailbox.pop
      throw Terminate if message == Terminate
      on_message message
    rescue => error
      logger.fatal error
    end

  end

  class MicroActorWithFutures < MicroActor
    def <<(message, future = Future.new)
      @mailbox << [message, future]
      future
    end

    def receive
      message, future = @mailbox.pop
      throw Terminate if message == Terminate
      future.resolve on_message(message)
    rescue => error
      logger.fatal error
    end
  end
end
