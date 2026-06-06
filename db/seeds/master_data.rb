puts "Creating master data..."

# Roles
Role.find_or_create_by!(name: "admin")
Role.find_or_create_by!(name: "manager")
Role.find_or_create_by!(name: "member")
Role.find_or_create_by!(name: "observer")

# Rooms and Keys
rooms_data = [
  { name: "第１部室", room_number: "322" },
  { name: "第２部室", room_number: "321" },
  { name: "第３部室", room_number: "224" }
]

rooms_data.each do |room_data|
  room = Room.find_or_create_by!(room_number: room_data[:room_number]) do |r|
    r.name = room_data[:name]
  end

  existing_keys_count = Key.where(room_id: room.id).count
  missing_keys_count = 5 - existing_keys_count
  missing_keys_count.times do
    Key.create!(room_id: room.id, user_id: nil)
  end
end

puts "  - #{Role.count} roles"
puts "  - #{Room.count} rooms"
puts "  - #{Key.count} keys"
