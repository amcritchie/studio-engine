# frozen_string_literal: true

module Studio
  # Mixin for ActiveRecord models that broadcast Turbo Streams. It wraps
  # turbo-rails' broadcast_*_to methods in Studio::Cable.safe_broadcast, so a cable
  # failure (a Redis hiccup, a missing/misconfigured adapter) can NEVER break the
  # model save / after_commit that triggered the broadcast — the SEV-1 guard, in
  # one place. The host model already has the raw broadcast_*_to methods (turbo-rails
  # includes Turbo::Broadcastable into ActiveRecord::Base); these are the SAFE
  # variants every app should broadcast through.
  #
  #   class Task < ApplicationRecord
  #     include Studio::Broadcastable
  #     after_create_commit { safe_broadcast_replace_to [:board], target: "card_#{id}",
  #                                                       partial: "tasks/card", locals: { task: self } }
  #   end
  module Broadcastable
    extend ActiveSupport::Concern

    def safe_broadcast_replace_to(*args, **kwargs, &block)
      Studio::Cable.safe_broadcast { broadcast_replace_to(*args, **kwargs, &block) }
    end

    def safe_broadcast_update_to(*args, **kwargs, &block)
      Studio::Cable.safe_broadcast { broadcast_update_to(*args, **kwargs, &block) }
    end

    def safe_broadcast_append_to(*args, **kwargs, &block)
      Studio::Cable.safe_broadcast { broadcast_append_to(*args, **kwargs, &block) }
    end

    def safe_broadcast_prepend_to(*args, **kwargs, &block)
      Studio::Cable.safe_broadcast { broadcast_prepend_to(*args, **kwargs, &block) }
    end

    def safe_broadcast_remove_to(*args, **kwargs, &block)
      Studio::Cable.safe_broadcast { broadcast_remove_to(*args, **kwargs, &block) }
    end
  end
end
