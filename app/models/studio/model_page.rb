# frozen_string_literal: true

require "json"

module Studio
  # The model-page protocol (v1).
  #
  # A reusable, per-record inspector. Given a whitelisted model key and a record
  # identifier, it produces the two things a v1 model page renders — the record
  # as pretty-printed JSON and a copy/paste rails-console command that reloads it
  # — plus the lookup a "random sample" jump needs. The controller and view stay
  # thin; enabling a model is a one-line registration.
  #
  # The engine ships an EMPTY registry: no model is reachable until a host app
  # opts in. Each app registers its own models in an initializer, e.g.
  #
  #   Studio::ModelPage.register("release", Release, lookup: :slug)
  #
  # This mirrors the admin-models pattern — the host hands the engine live class
  # references; the engine never constantizes host models by name. An unknown key
  # raises UnknownModel, which the controller renders as 404.
  class ModelPage
    class UnknownModel < StandardError; end

    Entry = Struct.new(:model, :lookup, keyword_init: true)

    class << self
      # Enable a model. `model` is the live AR class; `lookup` is the column its
      # page URL is keyed on (usually its to_param backing). Returns the key.
      def register(key, model, lookup: :slug)
        registry[key.to_s] = Entry.new(model: model, lookup: lookup.to_sym)
        key.to_s
      end

      def registered?(key)
        registry.key?(key.to_s)
      end

      def keys
        registry.keys
      end

      # Clears the registry — for tests and boot-time re-registration.
      def reset!
        registry.clear
      end

      def entry(key)
        registry.fetch(key.to_s) { raise UnknownModel, "unknown model: #{key.inspect}" }
      end

      private

      def registry
        @registry ||= {}
      end
    end

    attr_reader :model_key, :identifier

    # identifier is the record's lookup-key value from the URL (nil for /random,
    # which addresses the model as a whole rather than one record).
    def initialize(model_key, identifier = nil)
      @entry = self.class.entry(model_key)
      @model_key = model_key.to_s
      @identifier = identifier
    end

    def model
      @entry.model
    end

    def lookup_key
      @entry.lookup
    end

    # The record this page addresses (nil when the identifier matches nothing).
    def record
      return @record if defined?(@record)

      @record = model.find_by(lookup_key => identifier)
    end

    # A random record of this model, for the "random sample" jump (nil if empty).
    def random_record
      model.order(::Arel.sql("RANDOM()")).first
    end

    # The copy/paste rails-console command that reloads this record, e.g.
    #   Release.find_by(slug: "rel-20260707-a1b2c3")
    def console_command
      %(#{model.name}.find_by(#{lookup_key}: #{identifier.inspect}))
    end

    # The record serialized as pretty JSON — the page's primary payload.
    def json
      ::JSON.pretty_generate(record.as_json)
    end

    # The lookup-key value to route to for a given record (used by /random).
    def identifier_for(record)
      record.public_send(lookup_key)
    end
  end
end
