# The configuration is read from SYNCHRONIST_* environment variables now
class DropConfigs < ActiveRecord::Migration[8.1]
  def change
    drop_table :configs do |t|
      t.string :name, null: false, index: { unique: true }
      t.string :value
      t.timestamps
    end
  end
end
