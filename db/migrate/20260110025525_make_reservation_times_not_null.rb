class MakeReservationTimesNotNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :reservations, :start_at, false
    change_column_null :reservations, :end_at, false
  end
end
