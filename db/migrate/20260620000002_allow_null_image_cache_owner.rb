# Lets ImageCache cache app-GLOBAL images (no owning record) — e.g. Studio::
# EmailImage stores the admin-managed email banners owner-less. Reference
# migration; each consumer app installs its own copy (the table is app-owned).
class AllowNullImageCacheOwner < ActiveRecord::Migration[7.2]
  def change
    change_column_null :image_caches, :owner_type, true
    change_column_null :image_caches, :owner_id, true
  end
end
