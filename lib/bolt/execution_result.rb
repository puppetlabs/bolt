module Bolt
  class ExecutionResult
    if Object.const_defined?(:Puppet) && Puppet.const_defined?(:Pops)
      include Puppet::Pops::Types::Iterable
      include Puppet::Pops::Types::IteratorProducer

      def iterator
        tc = Puppet::Pops::Types::TypeFactory
        Puppet::Pops::Types::Iterable.on(
          @result_hash,
          tc.tuple([tc.string, tc.data], Puppet::Pops::Types::PHashType::KEY_PAIR_TUPLE_SIZE)
        )
      end

      def to_s
        Puppet::Pops::Types::StringConverter.singleton.convert(self)
      end
    else
      def iterator
        @result_hash.each
      end
    end

    # Creates a pure Data hash from a result hash returned from the Bolt::Executor
    # @return [Hash{String => Data}] The data hash
    def self.from_bolt(result_hash)
      data_result = {}
      result_hash.each_pair { |k, v| data_result[k.uri] = v.to_h }
      new(data_result)
    end

    attr_reader :result_hash

    def initialize(result_hash, final = false)
      result_hash = convert_errors(result_hash) unless final
      @result_hash = result_hash
    end

    def count
      @result_hash.size
    end

    def empty
      @result_hash.empty?
    end
    alias empty? empty

    def error_nodes
      result = {}
      @result_hash.each_pair { |k, v| result[k] = v if v.is_a?(Puppet::DataTypes::Error) }
      self.class.new(result, true)
    end

    def names
      @result_hash.keys
    end

    def ok
      @result_hash.values.none? { |v| v.is_a?(Puppet::DataTypes::Error) }
    end
    alias ok? ok

    def ok_nodes
      result = {}
      @result_hash.each_pair { |k, v| result[k] = v unless v.is_a?(Error) }
      self.class.new(result, true)
    end

    def [](node_uri)
      @result_hash[node_uri]
    end

    def value(node_uri)
      self[node_uri]
    end

    def values
      @result_hash.values
    end

    def _pcore_init_hash
      @result_hash
    end

    def eql?(other)
      self.class == other.class && @result_hash == other.result_hash
    end

    def ==(other)
      eql?(other)
    end

    private

    def convert_errors(result_hash)
      converted = {}
      result_hash.each_pair { |k, v| converted[k] = convert_error(v) }
      converted
    end

    def convert_error(value_or_error)
      e = value_or_error['error']
      v = value_or_error['value']
      e.nil? ? v : Puppet::DataTypes::Error.new(e['msg'], e['kind'], e['issue_code'], v, e['details'])
    end

    EMPTY_RESULT = new({})
  end
end
