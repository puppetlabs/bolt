# frozen_string_literal: true

module Bolt
  class ResultSet
    attr_reader :results

    include Enumerable

    # We only want want to include these when puppet is loaded
    def self.include_iterable
      include(Puppet::Pops::Types::Iterable)
      include(Puppet::Pops::Types::IteratorProducer)
    end

    def self.from_apply_block(resultset)
      results = resultset.results.map do |result|
        Bolt::Result.from_apply_block(result)
      end
      new(results)
    end

    #    def self._pcore_init_from_hash(init_hash); end
    #
    #    def _pcore_init_from_hash(init_hash)
    #      # What the fuck
    #      Bolt::ResultSet.new(init_hash['results'])
    #    end
    #
    #    def _pcore_init_hash
    #      { results: @results }
    #    end

    def iterator
      if Object.const_defined?(:Puppet) && Puppet.const_defined?(:Pops) &&
         self.class.included_modules.include?(Puppet::Pops::Types::Iterable)
        Puppet::Pops::Types::Iterable.on(@results, Bolt::Result)
      else
        raise NotImplementedError, "iterator requires puppet code to be loaded."
      end
    end

    def initialize(results)
      @results = results
    end

    def each
      @results.each { |r| yield r }
      self
    end

    def filter_set
      filtered = @results.select { |r| yield r }
      self.class.new(filtered)
    end

    def result_hash
      @result_hash ||= @results.each_with_object({}) do |result, acc|
        acc[result.target.name] = result
      end
    end

    def count
      @results.size
    end
    alias length count
    alias size count

    def empty
      @results.empty?
    end
    alias empty? empty

    def targets
      results.map(&:target)
    end

    def names
      @results.map { |r| r.target.name }
    end

    def ok
      @results.all?(&:ok?)
    end
    alias ok? ok

    def error_set
      filtered = @results.reject(&:ok?)
      ResultSet.new(filtered)
    end

    def ok_set
      filtered = @results.select(&:success?)
      self.class.new(filtered)
    end

    def find(target_name)
      result_hash[target_name]
    end

    def first
      @results.first
    end

    def eql?(other)
      self.class == other.class && @results == other.results
    end

    def to_a
      @results.map(&:status_hash)
    end

    def to_json(opts = nil)
      @results.map(&:status_hash).to_json(opts)
    end

    def to_data
      @results.map(&:to_data)
    end

    def to_s
      to_json
    end

    def ==(other)
      eql?(other)
    end

    def [](from, up_to = nil)
      if up_to
        @results[from..up_to]
      else
        @results[from]
      end
    end
  end
end
