# db/mock_data_script.rb

puts "--- Creating Mock Data ---"

# 1. Create Rooms
room1 = Room.find_or_create_by!(name: "第1部室", room_number: "101")
room2 = Room.find_or_create_by!(name: "第2部室", room_number: "201")
room3 = Room.find_or_create_by!(name: "第3部室", room_number: "301")
puts "Rooms: #{Room.count}"

# 2. Create Users (Ensure enough users exist)
# We need at least 3 (res) + 15 (keys) = 18 users.
current_count = User.count
needed = 20 - current_count
if needed > 0
  needed.times do |i|
    User.create!(
      username: "user_#{current_count + i}",
      display_name: "User #{current_count + i + 1}",
      discord_id: "mock_#{current_count + i}",
      jyogi_user_id: SecureRandom.uuid
    )
  end
end
users = User.all.to_a
puts "Users: #{User.count}"

# 3. Create Reservations for Today (3 items)
Reservation.where(start_at: Time.current.all_day).destroy_all
today = Time.current.to_date

Reservation.create!(
  user: users[0],
  start_at: today.in_time_zone.change(hour: 10, min: 0),
  end_at: today.in_time_zone.change(hour: 12, min: 0)
)
Reservation.create!(
  user: users[1],
  start_at: today.in_time_zone.change(hour: 13, min: 0),
  end_at: today.in_time_zone.change(hour: 15, min: 0)
)
Reservation.create!(
  user: users[2],
  start_at: today.in_time_zone.change(hour: 16, min: 0),
  end_at: today.in_time_zone.change(hour: 18, min: 0)
)
puts "Reservations (Today): #{Reservation.where(start_at: today.all_day).count}"

# 4. Create Keys (5 holders per room)
if Rails.env.production? && ENV['ALLOW_MOCK_DATA'] != 'true'
  puts "⚠️ Scip destructive operations in production (ALLOW_MOCK_DATA!=true)"
else
  Key.destroy_all # Reset keys for clean state
end

# Room 1 holders (users 0-4)
if users.length >= 5
  users[0..4].each do |user|
    Key.create!(user: user, room: room1)
  end
end

# Room 2 holders (users 5-9)
if users.length >= 10
  users[5..9].each do |user|
    Key.create!(user: user, room: room2)
  end
end

# Room 3 holders (users 10-14)
if users.length >= 15
  users[10..14].each do |user|
    Key.create!(user: user, room: room3)
  end
end

puts "Keys: #{Key.count}"
puts "--- Mock Data Created Successfully ---"
