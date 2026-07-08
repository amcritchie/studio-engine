# frozen_string_literal: true

require "test_helper"

# Minimal Arel stub so ModelPage#random_record can build its RANDOM() order
# without booting a full Rails / ActiveRecord stack in this pure-Ruby unit test.
module Arel
  def self.sql(str)
    str
  end
end unless defined?(Arel)

module Studio
  class ModelPageTest < Minitest::Test
    # A tiny stand-in for a host ActiveRecord record.
    FakeRecord = Struct.new(:slug, :state) do
      def as_json(*)
        { "slug" => slug, "state" => state }
      end
    end

    # A tiny stand-in for a host ActiveRecord model class.
    class FakeModel
      def self.seed!(*records)
        @records = records
      end

      def self.records
        @records ||= []
      end

      def self.name
        "Release"
      end

      def self.find_by(conditions)
        key, value = conditions.first
        records.find { |r| r.public_send(key) == value }
      end

      def self.order(_sql)
        self
      end

      def self.first
        records.first
      end
    end

    def setup
      Studio::ModelPage.reset!
      FakeModel.seed!(FakeRecord.new("rel-a", "shipped"), FakeRecord.new("rel-b", "assembling"))
      Studio::ModelPage.register("release", FakeModel, lookup: :slug)
    end

    def teardown
      Studio::ModelPage.reset!
    end

    def test_registration_tracks_enabled_keys
      assert Studio::ModelPage.registered?("release")
      refute Studio::ModelPage.registered?("nope")
      assert_equal ["release"], Studio::ModelPage.keys
    end

    def test_empty_registry_by_default
      Studio::ModelPage.reset!
      refute Studio::ModelPage.registered?("release")
      assert_empty Studio::ModelPage.keys
    end

    def test_unknown_model_raises
      assert_raises(Studio::ModelPage::UnknownModel) { Studio::ModelPage.new("nope", "x") }
    end

    def test_resolves_model_and_lookup_key
      page = Studio::ModelPage.new("release", "rel-a")

      assert_equal FakeModel, page.model
      assert_equal :slug, page.lookup_key
    end

    def test_finds_record_by_lookup_key
      page = Studio::ModelPage.new("release", "rel-a")

      assert_equal "rel-a", page.record.slug
    end

    def test_record_is_nil_when_identifier_matches_nothing
      page = Studio::ModelPage.new("release", "missing")

      assert_nil page.record
    end

    def test_console_command_is_copy_paste_find_by_on_the_lookup_key
      page = Studio::ModelPage.new("release", "rel-20260707-a1b2c3")

      assert_equal %(Release.find_by(slug: "rel-20260707-a1b2c3")), page.console_command
    end

    def test_json_pretty_prints_the_record
      page = Studio::ModelPage.new("release", "rel-a")

      parsed = JSON.parse(page.json)
      assert_equal "rel-a", parsed["slug"]
      assert_includes page.json, "\n", "pretty JSON should be multi-line"
    end

    def test_random_record_returns_a_record_when_populated
      page = Studio::ModelPage.new("release", nil)

      assert_kind_of FakeRecord, page.random_record
    end

    def test_identifier_for_reads_the_lookup_key_off_a_record
      page = Studio::ModelPage.new("release", nil)

      assert_equal "rel-a", page.identifier_for(FakeRecord.new("rel-a", "x"))
    end
  end
end
