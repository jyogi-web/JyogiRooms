class AddIndexToReservations < ActiveRecord::Migration[8.1]
  def change
    add_index :reservations, [:start_at, :end_at]
  end
end
