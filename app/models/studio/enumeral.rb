module Studio
  # A shared, DB-backed enumeration table for the whole ecosystem. Every "list of
  # fixed, labeled, colored values" — Pokémon types (its first use), and later
  # statuses, tiers, roles, … — is just rows in ONE studio_enumerals table,
  # grouped by `category`. Each row is identity + presentation: a stable machine
  # `key` ("fire"), a human `label` ("Fire"), a `color` hex ("#EE8130"), and a
  # `position` for ordering within its category. `metadata` (jsonb) carries any
  # category-specific extras off the columns.
  #
  # Shipped by the gem like Studio::Link / Studio::EmailDelivery: the model lives
  # here, the table lives in each consumer app (copy the reference migration into
  # db/migrate). No behavior is attached — it is pure reference data the apps
  # read, so a consumer adopts a new category by seeding rows, no code change.
  class Enumeral < ApplicationRecord
    self.table_name = "studio_enumerals"

    HEX = /\A#(?:\h{3}|\h{6})\z/

    validates :category, presence: true
    validates :key, presence: true,
                    uniqueness: { scope: :category, case_sensitive: false }
    validates :color, format: { with: HEX, message: "must be a hex color like #EE8130" },
                      allow_blank: true

    scope :in_category, ->(category) { where(category: category.to_s) }
    scope :ordered,     -> { order(:position, :key) }
    # By `rank` (a sparse 100/200/… domain ranking), nulls last — for categories
    # ordered by something other than display position, e.g. most-common-first.
    scope :by_rank,     -> { order(:rank) }

    class << self
      # True only when the table is actually migrated in this app's DB, so a
      # consumer that hasn't installed the migration degrades to "empty" instead
      # of crashing (mirrors Studio::EmailDelivery.available?).
      def available?
        connection.data_source_exists?(table_name)
      rescue ActiveRecord::ActiveRecordError, NoMethodError
        false
      end

      # The ordered list of a category's enumerals — the relation a view iterates
      # (one query). Returns an empty relation when the table isn't installed yet,
      # so callers can `.each` safely pre-migration.
      def catalog(category)
        return none unless available?

        in_category(category).ordered
      end

      # The single enumeral for (category, key), or nil.
      def lookup(category, key)
        return nil unless available?

        in_category(category).find_by(key: key.to_s)
      end

      # { key => color } for a category in ONE query — the shape a view wants:
      # build it once, then look up each cell with no extra queries (avoids an
      # N+1 when rendering many rows, e.g. the /pokemon type badges).
      def color_map(category)
        catalog(category).pluck(:key, :color).to_h
      end

      # Just the color for a single (category, key), with an optional fallback
      # when the key is unknown or the table isn't installed yet.
      def color_for(category, key, fallback: nil)
        return fallback unless available?

        in_category(category).where(key: key.to_s).limit(1).pick(:color) || fallback
      end
    end
  end
end
