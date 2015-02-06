module Sprig::Reap
  class Model
    include Logging

    def self.all
      @@all ||= begin
        models = Sprig::Reap.classes.map { |klass| new(klass) }

        tsorted_classes(models).map do |klass|
          models.find { |model| model.klass == klass }
        end
      end
    end

    def self.find(klass, id)
      all.find { |model| model.klass == klass }.find(id)
    end

    attr_reader :klass
    attr_reader :relation
    attr_writer :existing_sprig_ids

    def initialize(klass)
      if klass.kind_of?(ActiveModel::Relation)
        @klass = klass.klass
        @realtion = klass
      else
        @klass = klass
        @relation = klass.all
      end
    end

    def attributes
      klass.column_names - Sprig::Reap.ignored_attrs
    end

    def dependencies
      @dependencies ||= associations
        .reject do |association|
          Sprig::Reap.ignored_dependencies(klass).include?(association.association.name)
        end
        .flat_map(&:dependencies)
    end

    def associations
      @associations ||= klass.reflect_on_all_associations(:belongs_to).map do |association|
        Association.new(association)
      end
    end

    def existing_sprig_ids
      @existing_sprig_ids ||= []
    end

    def generate_sprig_id
      existing_sprig_ids.select { |i| i.is_a? Integer }.sort.last + 1
    end

    def find(id)
      records.find { |record| record.id == id }
    end

    def to_s
      klass.to_s
    end

    def to_yaml(options = {})
      return if records.empty?

      namespace         = options[:namespace]
      formatted_records = records.map(&:to_hash)

      yaml = if namespace
        { namespace => formatted_records }.to_yaml
      else
        formatted_records.to_yaml
      end

      yaml.gsub("---\n", '') # Remove annoying YAML separator
    end

    def records
      @records ||= relation.all.map { |record| Record.new(record, self) }
    rescue => e
      log_error "Encountered an error when pulling the database records for #{to_s}:\r#{e.message}"
      []
    end

    private

    def self.tsorted_classes(models)
      begin
        models.reduce(TsortableHash.new) do |hash, model|
          hash.merge(model.klass => model.dependencies)
        end.tsort
      rescue KeyError(e)
        log_error "Missing dependency "
      end
    end
  end
end
