puts "Creating development data..."

# Clear existing data（マスターデータは残す）
puts "Cleaning up database..."
KeyTransferLog.delete_all
Key.where.not(user_id: nil).update_all(user_id: nil)
AccessToken.delete_all
Reservation.delete_all
User.delete_all

room1 = Room.find_by!(room_number: "322")
room2 = Room.find_by!(room_number: "321")
room3 = Room.find_by!(room_number: "224")

admin_role = Role.find_by!(name: "admin")
member_role = Role.find_by!(name: "member")

# Create Users
puts "Creating Users..."
user1 = User.create!(username: "test_user1", display_name: "1(テストユーザー)")
user2 = User.create!(username: "test_user2", display_name: "2(テストユーザー)")
user3 = User.create!(username: "test_user3", display_name: "3(テストユーザー)")
user4 = User.create!(username: "test_user4", display_name: "4(テストユーザー)")
user5 = User.create!(username: "test_user5", display_name: "5(テストユーザー)")

# Assign Roles
puts "Assigning roles..."
user1.update!(role: admin_role)
[ user2, user3, user4, user5 ].each { |u| u.update!(role: member_role) }

seed_admin_username = ENV["SEED_ADMIN_USERNAME"] || "test_user5"
admin_target = User.find_by(username: seed_admin_username)
if admin_target
  admin_target.update!(role: admin_role)
  puts "Assigned admin role to #{admin_target.username}"
else
  puts "No admin assigned: user '#{seed_admin_username}' not found"
end

# Assign Keys
puts "Assigning Keys..."
Key.find_by(room: room1, user_id: nil)&.update!(user: user1)
Key.find_by(room: room1, user_id: nil)&.update!(user: user2)
Key.find_by(room: room2, user_id: nil)&.update!(user: user2)
Key.find_by(room: room3, user_id: nil)&.update!(user: user3)
Key.find_by(room: room3, user_id: nil)&.update!(user: user4)

# Create sample KeyTransferLogs
puts "Creating KeyTransferLogs..."
KeyTransferLog.create!(room: room1, from_user: user3, to_user: user1, created_at: 3.days.ago)
KeyTransferLog.create!(room: room2, from_user: user1, to_user: user2, created_at: 1.day.ago)

puts "Done! Created:"
puts "  - #{User.count} users"
puts "  - #{Key.where.not(user_id: nil).count} assigned keys"
puts "  - #{KeyTransferLog.count} transfer logs"
