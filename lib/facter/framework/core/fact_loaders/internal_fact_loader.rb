# frozen_string_literal: true

module Facter
  class InternalFactLoader

    def core_facts(user_query = nil)
      load_facts(user_query)
      @facts.select { |fact| fact.type == :core }
    end

    def legacy_facts(user_query = nil)
      load_facts(user_query)
      @facts.select { |fact| fact.type == :legacy }
    end

    def facts(user_query = nil)
      load_facts(user_query)
      @facts
    end

    def initialize(os_descendents = nil)
      @facts = []
      @os_descendents ||= OsDetector.instance.hierarchy
    end


    private

     def load_facts(user_query)
      load_all_oses_in_descending_order(@os_descendents, user_query)
    end

    def load_all_oses_in_descending_order(os_descendents, user_query = nil)
      os_descendents.reverse_each do |os|
        load_for_os(os, user_query)
      end
    end

    def load_for_os(operating_system, user_query = nil)
      # select only classes
      classes = ClassDiscoverer.instance.discover_classes(operating_system)
      classes.each do |class_name|
        fact_name = class_name::FACT_NAME
        # if fact is already loaded, skip it

        next if user_query.instance_of?(String) && fact_name !~ /^#{user_query}/

        unless @facts.any? { |fact| fact.name == fact_name }
          type = class_name.const_defined?('TYPE') ? class_name::TYPE : :core
          load_fact(fact_name, class_name, type)
        end
        next unless class_name.const_defined?('ALIASES')

        [*class_name::ALIASES].each do |fact_alias|
          load_fact(fact_alias, class_name, :legacy) unless @facts.any? { |fact| fact.name == fact_alias }
        end
      end
    end

    def load_fact(fact_name, klass, type)
      loaded_fact = LoadedFact.new(fact_name, klass, type)
      @facts << loaded_fact
    end
  end
end
