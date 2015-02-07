module Sprig::Reap
  class Configuration

    def target_env
      @target_env ||= Rails.env
    end

    def target_env=(given_env)
      parse_valid_env_from given_env do |target_environment|
        @target_env = target_environment
      end
    end

    def classes
      @classes ||= valid_classes
    end

    def classes=(given_classes)
      parse_valid_classes_from given_classes do |classes|
        @classes = classes
      end
    end

    def ignored_attrs
      @ignored_attrs ||= []
    end

    def ignored_attrs=(input)
      @ignored_attrs = parse_ignored_attrs_from(input)
    end

    def ignored_dependencies(klass)
      return [] unless @ignored_dependencies
      key = klass.model_name.singular.to_sym
      @ignored_dependencies[key] + @ignored_dependencies[:all]
    end

    def ignored_dependencies=(input)
      @ignored_dependencies = parse_ignored_dependencies_from_input(input)
    end

    def logger
      @logger ||= Logger.new($stdout)
    end

    def omit_empty_attrs
      @omit_empty_attrs ||= false
    end

    def omit_empty_attrs=(input)
      @omit_empty_attrs = true if String(input).strip.downcase == 'true'
    end

    private

    def valid_classes
      @valid_classes ||= begin
        Rails.application.eager_load!
        ActiveRecord::Base.subclasses
      end
    end

    def parse_valid_env_from(input)
      return if input.nil?
      target_environment = input.to_s.strip.downcase
      create_seeds_folder(target_environment)
      yield target_environment
    end

    def create_seeds_folder(target_env)
      folder = Rails.root.join('db', 'seeds', target_env)
      FileUtils.mkdir_p(folder) unless File.directory? folder
    end

    def parse_valid_classes_from(input)
      return if input.nil?

      classes = if input.is_a? String
        input.split(',').map { |klass_string| klass_string.strip.classify.constantize }
      else
        input
      end

      validate_classes(classes)

      yield classes
    end

    def validate_classes(classes)
      classes.each do |klass|
        unless valid_classes.include?(klass) || klass.kind_of?(ActiveRecord::Relation)
          raise ArgumentError, "Cannot create a seed file for #{klass} because it is not a subclass of ActiveRecord::Base."
        end
      end
    end

    def parse_ignored_attrs_from(input)
      return if input.nil?

      if input.is_a? String
        input.split(',').map(&:strip)
      else
        input.map(&:to_s).map(&:strip)
      end
    end

    def parse_ignored_dependencies_from_input(input)
      return {} unless input

      unless input.all? { |k,v| v.kind_of? Array }
        raise ArgumentError, "Cannot parse ignored dependencies. Must be a hash of the form { klass => [relation, relation]}"
      end

      h = input.symbolize_keys
      h.default = []
      h
    end
  end
end
