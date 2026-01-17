class AddPurposeToReservations < ActiveRecord::Migration[8.1]
  def change
    add_column :reservations, :purpose, :string
  end
end
