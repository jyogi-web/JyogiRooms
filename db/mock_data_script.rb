# db/mock_data_script.rb

puts "--- Creating Mock Data ---"

# 1. Create Rooms
room1 = Room.find_or_create_by!(name: "第1部室", room_number: "322")
room2 = Room.find_or_create_by!(name: "第2部室", room_number: "321")
room3 = Room.find_or_create_by!(name: "第3部室", room_number: "224")
puts "Rooms: #{Room.count}"

# 2. Create Users (Ensure enough users exist)
# We need at least 3 (res) + 15 (keys) = 18 users.
if Rails.env.production? && ENV['ALLOW_MOCK_DATA'] != 'true'
  puts "⚠️ Skip creating mock users in production (ALLOW_MOCK_DATA!=true)"
  puts "   Current Users: #{User.count}"
else
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
end
users = User.all.to_a
puts "Users: #{User.count}"

# 3. Create Reservations for Today (3 items)
if Rails.env.production? && ENV['ALLOW_MOCK_DATA'] != 'true'
  puts "⚠️ Skip destructive operations in production (ALLOW_MOCK_DATA!=true)"
else
  target_day = Time.current.tomorrow
  Reservation.where(start_at: target_day.all_day).destroy_all
  target_date = target_day.to_date

  if users.length >= 3
    Reservation.create!(
      user: users[0],
      start_at: target_date.in_time_zone.change(hour: 10, min: 0),
      end_at: target_date.in_time_zone.change(hour: 12, min: 0),
      purpose: "定例会議"
    )
    Reservation.create!(
      user: users[1],
      start_at: target_date.in_time_zone.change(hour: 13, min: 0),
      end_at: target_date.in_time_zone.change(hour: 15, min: 0),
      purpose: "採用面接"
    )
    Reservation.create!(
      user: users[2],
      start_at: target_date.in_time_zone.change(hour: 16, min: 0),
      end_at: target_date.in_time_zone.change(hour: 18, min: 0),
      purpose: "もくもく会"
    )
  else
    puts "⚠️ Not enough users to create mock reservations (need at least 3)"
  end
end
puts "Reservations (Tomorrow): #{Reservation.where(start_at: Time.current.tomorrow.all_day).count}"

# 4. Create Keys (5 holders per room)
if Rails.env.production? && ENV['ALLOW_MOCK_DATA'] != 'true'
  puts "⚠️ Skip destructive operations in production (ALLOW_MOCK_DATA!=true)"
else
  Key.destroy_all # Reset keys for clean state

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
end

puts "Keys: #{Key.count}"
puts "--- Mock Data Created Successfully ---"
