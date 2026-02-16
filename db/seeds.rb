# Guard against accidental deletion in production
return unless Rails.env.development? || Rails.env.test?

# Clear existing data（マスターデータは残す）
puts "Cleaning up database..."
KeyTransferLog.delete_all
Key.where.not(user_id: nil).update_all(user_id: nil)  # リセット: 割り当てられたキーのみuser_idをクリア
AccessToken.delete_all
Reservation.delete_all
User.delete_all

# Get master data (created by migration)
puts "Getting master rooms and roles..."
room1 = Room.find_by(room_number: "322")
room2 = Room.find_by(room_number: "321")
room3 = Room.find_by(room_number: "224")

admin_role = Role.find_by(name: Role::ADMIN)
member_role = Role.find_by(name: Role::MEMBER)

# Create Users
puts "Creating Users..."
user1 = User.create!(
  username: "test_user1",
  display_name: "1(テストユーザー)"
)
user2 = User.create!(
  username: "test_user2",
  display_name: "2(テストユーザー)"
)
user3 = User.create!(
  username: "test_user3",
  display_name: "3(テストユーザー)"
)
user4 = User.create!(
  username: "test_user4",
  display_name: "4(テストユーザー)"
)
user5 = User.create!(
  username: "test_user5",
  display_name: "5(テストユーザー)"
)

# Create Roles
puts "Creating Roles..."
# ロールはマイグレーションで既に作成されている

# Assign admin role to user1, member role to others
puts "Assigning roles to users..."
user1.update!(role: admin_role)
[ user2, user3, user4, user5 ].each do |u|
  u.update!(role: member_role)
end

# test_user5は管理者に設定
seed_admin_username = ENV["SEED_ADMIN_USERNAME"] || "test_user5"
admin_target = User.find_by(username: seed_admin_username)
if admin_target
  admin_target.update!(role: admin_role)
  puts "Assigned admin role to #{admin_target.username}"
else
  puts "No admin assigned: user '#{seed_admin_username}' not found"
end

# Create Keys (鍵の所有状態)
puts "Creating Keys..."
# マスターデータとしての空き鍵は既にマイグレーションで作成済み
# ここではユーザーに鍵を割り当てる
key1 = Key.find_by(room: room1, user_id: nil)
key1.update!(user: user1) if key1  # user1が第1部室の鍵を持つ

key2 = Key.find_by(room: room1, user_id: nil)
key2.update!(user: user2) if key2  # user2が第1部室の別の鍵を持つ

key3 = Key.find_by(room: room2, user_id: nil)
key3.update!(user: user2) if key3  # user2が第2部室の鍵も持つ

key4 = Key.find_by(room: room3, user_id: nil)
key4.update!(user: user3) if key4  # user3が第3部室の鍵を持つ

key5 = Key.find_by(room: room3, user_id: nil)
key5.update!(user: user4) if key5  # user4が第3部室の別の鍵を持つ

# user5は鍵を持っていない（譲渡先として使用）

# Create sample KeyTransferLogs (譲渡履歴のサンプル)
puts "Creating KeyTransferLogs..."
KeyTransferLog.create!(
  room: room1,
  from_user: user3,
  to_user: user1,
  created_at: 3.days.ago
)
KeyTransferLog.create!(
  room: room2,
  from_user: user1,
  to_user: user2,
  created_at: 1.day.ago
)

puts "Done! Created:"
puts "  - #{Room.count} rooms"
puts "  - #{User.count} users"
puts "  - #{Role.count} roles"
puts "  - #{Key.count} keys"
puts "  - #{KeyTransferLog.count} transfer logs"
