module Jobster
  class Job

    class Abort < StandardError; end

    attr_reader :id
    attr_reader :params

    def initialize(id, params = {})
      @id = id
      @params = params.with_indifferent_access
    end

    def perform
      # Override in child jobs
    end

    def log(text)
      Jobster.config.logger.info "[#{@id}] #{text}"
    end

    def self.description(params)
      self.name
    end

    def description
      self.class.description(@params)
    end

    def self.queue(queue = {}, params = {}, &block)
      queue, params = parse_args_for_queue(queue, params)
      self.queue_job(Jobster.exchange, queue, self, params, &block)
    end

    def self.queue_with_delay(delay, queue = {}, params = {}, &block)
      queue, params = parse_args_for_queue(queue, params)
      self.queue_job(Jobster.delay_exchange, queue, self, params, :ttl => delay, &block)
    end

    def self.parse_args_for_queue(queue, params)
      queue.is_a?(Hash) ? [:main, queue] : [queue, params]
    end

    def self.queue_job(exchange, queue_name, klass, params, options = {}, &block)
      job_id = SecureRandom.uuid[0,8]
      job_payload = {'params' => params, 'class_name' => klass.name, 'id' => job_id, 'queue' => queue_name}
      publish_opts = {}
      publish_opts[:persistent] = true
      publish_opts[:routing_key] = queue_name
      publish_opts[:expiration] = options[:ttl] * 1000 if options[:ttl]
      block.call(job_id, publish_opts) if block_given?
      a = exchange.publish(job_payload.to_json, publish_opts)
      when_string = (options[:ttl] ? "in #{options[:ttl]}s" : "immediately")
      Jobster.config.logger.info "[#{job_id}] \e[34m#{klass.description(params)}\e[0m queued to run #{when_string} on #{queue_name} queue"
      job_id
    end

    def self.perform(params = {})
      new(nil, params).perform
    end

  end
end
