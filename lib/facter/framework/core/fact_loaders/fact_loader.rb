# frozen_string_literal: true

module Facter
  class FactLoader
    include Singleton

    attr_reader :internal_facts, :external_facts, :facts

    def initialize
      @log = Log.new(self)

      @internal_facts = []
      @external_facts = []
      @custom_facts = []
      @facts = []

      @internal_loader ||= InternalFactLoader.new
      @external_fact_loader ||= ExternalFactLoader.new
    end

    def load(user_query, options)
      @internal_facts = load_internal_facts(user_query, options)
      @custom_facts = load_custom_facts(options)
      @external_facts = load_external_facts(options)

      filter_env_facts

      @facts = @internal_facts + @external_facts + @custom_facts
    end

    def load_internal_facts(user_query, options)
      @log.debug('Loading internal facts')
      internal_facts = []
      if user_query || options[:show_legacy]
        # if we have a user query, then we must search in core facts and legacy facts
        @log.debug('Loading all internal facts')
        internal_facts = @internal_loader.facts(user_query)
      else
        @log.debug('Load only core facts')
        internal_facts = @internal_loader.core_facts(user_query)
      end

      block_facts(internal_facts, options)
    end

    def load_custom_fact(options, fact_name)
      return [] unless options[:custom_facts]

      custom_facts = @external_fact_loader.load_fact(fact_name)
      block_facts(custom_facts, options)
    end

    def load_custom_facts(options)
      return [] unless options[:custom_facts]

      @log.debug('Loading custom facts')
      custom_facts = @external_fact_loader.custom_facts
      block_facts(custom_facts, options)
    end

    def load_external_facts(options)
      return [] unless options[:external_facts]

      @log.debug('Loading external facts')
      external_facts = @external_fact_loader.external_facts
      block_facts(external_facts, options)
    end

    private

    def filter_env_facts
      env_fact_names = @external_facts.select { |fact| fact.is_env == true }.map(&:name)
      return unless env_fact_names.any?

      @internal_facts.delete_if do |fact|
        if env_fact_names.include?(fact.name)
          @log.debug("Reading #{fact.name} fact from environment variable")
          true
        else
          false
        end
      end
    end

    def block_facts(facts, options)
      blocked_facts = options[:blocked_facts] || []

      facts.reject! { |fact| fact.type == :legacy } if options[:block_list]&.include?('legacy')

      return facts if blocked_facts.empty?

      reject_list_core, reject_list_legacy = construct_reject_lists(blocked_facts, facts)

      facts = facts.reject do |fact|
        reject_list_core.include?(fact) || reject_list_core.find do |fact_to_block|
          fact_to_block.klass == fact.klass
        end || reject_list_legacy.include?(fact)
      end

      facts
    end

    def construct_reject_lists(blocked_facts, facts)
      reject_list_core = []
      reject_list_legacy = []

      # matches fact_name.
      start_matcher = blocked_facts.map { |e| "^#{e}\\." }.join('|')
      # matches the full fact_name
      full_matcher = blocked_facts.map { |e| "^#{e}$" }.join('|')

      facts.each do |fact|
        fact_name = fact.name
        next unless  fact_name.start_with?(/#{start_matcher}/) || fact_name =~ /#{full_matcher}/

        if fact.type == :core
          reject_list_core << fact
        else
          reject_list_legacy << fact
        end
      end

      [reject_list_core, reject_list_legacy]
    end
  end
end
