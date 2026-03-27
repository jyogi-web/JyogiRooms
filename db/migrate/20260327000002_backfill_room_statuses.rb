class BackfillRoomStatuses < ActiveRecord::Migration[8.1]
  def up
    Room.find_each do |room|
      next if RoomStatus.exists?(room_id: room.id)

      session = RoomSession.where(room_id: room.id, closed_at: nil).first
      visits = RoomVisit.where(room_id: room.id, exited_at: nil)
                        .joins("INNER JOIN users ON users.id = room_visits.user_id")
                        .select("room_visits.user_id, users.display_name, room_visits.entered_at")

      occupants = visits.map do |v|
        { "user_id" => v.user_id, "display_name" => v.display_name, "entered_at" => v.entered_at.iso8601 }
      end

      RoomStatus.create!(
        room_id: room.id,
        is_open: session.present?,
        opened_at: session&.opened_at,
        opened_by_id: session&.opened_by_id,
        occupant_count: occupants.size,
        occupants: occupants
      )
    end
  end

  def down
    RoomStatus.delete_all
  end
end
