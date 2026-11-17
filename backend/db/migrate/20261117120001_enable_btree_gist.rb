# Needed by the salary_records exclusion constraint (DR-20): GiST over a bigint column plus a range.
class EnableBtreeGist < ActiveRecord::Migration[8.1]
  def change
    enable_extension "btree_gist"
  end
end
