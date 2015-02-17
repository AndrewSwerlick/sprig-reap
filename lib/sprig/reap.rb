require "sprig/reap/version"
require "sprig/reap/railtie"

module Sprig::Reap
  autoload :TsortableHash, 'sprig/reap/tsortable_hash'
  autoload :Configuration, 'sprig/reap/configuration'
  autoload :Model,         'sprig/reap/model'
  autoload :Association,   'sprig/reap/association'
  autoload :Record,        'sprig/reap/record'
  autoload :SeedFile,      'sprig/reap/seed_file'
  autoload :FileAttribute, 'sprig/reap/file_attribute'
  autoload :Logging,       'sprig/reap/logging'

  extend Logging

  class << self
    def reap(input = {})
      setup(input)

      log_debug "Reaping records from the database...\r"

      Model.all.each { |model| SeedFile.new(model).write }

      log_debug "Finished reaping!"
    end

    def setup(input = {})
      options = input.to_hash

      configure do |config|
        config.target_env           = options[:target_env]            || options['TARGET_ENV']
        config.classes              = options[:models]                || options['MODELS']
        config.ignored_attrs        = options[:ignored_attrs]         || options['IGNORED_ATTRS']
        config.ignored_dependencies = options[:ignored_dependencies]  || options['IGNORED_DEPENDENCIES']
        config.omit_empty_attrs     = options[:omit_empty_attrs]      || options['OMIT_EMPTY_ATTRS']
      end
    end

    def clear_config
      @@configuration = nil
    end

    def reset
      clear_config
      Sprig::Reap::Model.clear
    end

    private

    cattr_reader :configuration

    delegate :target_env,
             :classes,
             :ignored_attrs,
             :ignored_dependencies,
             :logger,
             :omit_empty_attrs,
             to: :configuration

    def configuration
      @@configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end
  end
end
