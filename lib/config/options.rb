require 'ostruct'
require 'config/validation/validate' if RUBY_VERSION >= '2.1'

module Config
  class Options < OpenStruct
    include Enumerable
    include Validation::Validate if RUBY_VERSION >= '2.1'

    def keys
      marshal_dump.keys
    end

    def empty?
      marshal_dump.empty?
    end

    def add_source!(source)
      # handle yaml file paths
      source = (Sources::YAMLSource.new(source)) if source.is_a?(String)
      source = (Sources::HashSource.new(source)) if source.is_a?(Hash)

      @config_sources ||= []
      @config_sources << source
    end

    def prepend_source!(source)
      source = (Sources::YAMLSource.new(source)) if source.is_a?(String)
      source = (Sources::HashSource.new(source)) if source.is_a?(Hash)

      @config_sources ||= []
      @config_sources.unshift(source)
    end

    def reload_env!
      return self if ENV.nil? || ENV.empty?

      hash = Hash.new

      ENV.each do |variable, value|
        keys = variable.to_s.split(Config.env_separator)

        next if keys.shift != (Config.env_prefix || Config.const_name)

        keys.map! { |key|
          case Config.env_converter
            when :downcase then
              key.downcase.to_sym
            when nil then
              key.to_sym
            else
              raise "Invalid ENV variables name converter: #{Config.env_converter}"
          end
        }

        leaf = keys[0...-1].inject(hash) { |h, key|
          h[key] ||= {}
        }

        leaf[keys.last] = Config.env_parse_values ? __value(value) : value
      end

      merge!(hash)
    end

    alias :load_env! :reload_env!

    # look through all our sources and rebuild the configuration
    def reload!
      conf = {}
      @config_sources.each do |source|
        source_conf = source.load

        if conf.empty?
          conf = source_conf
        else
          DeepMerge.deep_merge!(source_conf,
                                conf,
                                preserve_unmergeables: false,
                                knockout_prefix:       Config.knockout_prefix,
                                overwrite_arrays:      Config.overwrite_arrays)
        end
      end

      # swap out the contents of the OStruct with a hash (need to recursively convert)
      marshal_load(__convert(conf).marshal_dump)

      reload_env! if Config.use_env
      validate! if RUBY_VERSION >= '2.1'

      self
    end

    alias :load! :reload!

    def reload_from_files(*files)
      Config.load_and_set_settings(files)
      reload!
    end

    def to_hash
      marshal_dump.each_with_object({}) do |(k, v), result|
        if v.instance_of? Config::Options
          result[k] = v.to_hash
        elsif v.instance_of? Array
          result[k] = descend_array(v)
        else
          result[k] = v
        end
      end
    end

    def each(*args, &block)
      marshal_dump.each(*args, &block)
    end

    def to_json(*args)
      require "json" unless defined?(JSON)
      to_hash.to_json(*args)
    end

    def merge!(hash)
      current = to_hash
      DeepMerge.deep_merge!(hash.dup,
                            current,
                            preserve_unmergeables: false,
                            overwrite_arrays:      Config.overwrite_arrays)
      marshal_load(__convert(current).marshal_dump)
      self
    end

    # Some keywords that don't play nicely with OpenStruct
    SETTINGS_RESERVED_NAMES = %w{select collect test count}

    # An alternative mechanism for property access.
    # This let's you do foo['bar'] along with foo.bar.
    def [](param)
      return super if SETTINGS_RESERVED_NAMES.include?(param)
      send("#{param}")
    end

    def []=(param, value)
      send("#{param}=", value)
    end

    SETTINGS_RESERVED_NAMES.each do |name|
      define_method name do
        self[name]
      end
    end

    protected

    def descend_array(array)
      array.map do |value|
        if value.instance_of? Config::Options
          value.to_hash
        elsif value.instance_of? Array
          descend_array(value)
        else
          value
        end
      end
    end

    # Recursively converts Hashes to Options (including Hashes inside Arrays)
    def __convert(h) #:nodoc:
      s = self.class.new

      h.each do |k, v|
        k = k.to_s if !k.respond_to?(:to_sym) && k.respond_to?(:to_s)
        s.new_ostruct_member(k)

        if v.is_a?(Hash)
          v = v["type"] == "hash" ? v["contents"] : __convert(v)
        elsif v.is_a?(Array)
          v = v.collect { |e| e.instance_of?(Hash) ? __convert(e) : e }
        end

        s.send("#{k}=".to_sym, v)
      end
      s
    end

    # Try to convert string to a correct type
    def __value(v)
      Integer(v) rescue Float(v) rescue v
    end
  end
end
