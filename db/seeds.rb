# Guard against accidental deletion in production
return unless Rails.env.development? || Rails.env.test?

# Clear existing data
puts "Cleaning up database..."
KeyTransferLog.delete_all
Key.delete_all
AccessToken.delete_all
Reservation.delete_all
Room.delete_all
User.delete_all

# Create Rooms
puts "Creating Rooms..."
room1 = Room.create!(name: "第１部室", room_number: "322")
room2 = Room.create!(name: "第２部室", room_number: "321")
room3 = Room.create!(name: "第３部室", room_number: "224")

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

# Create Keys (鍵の所有状態)
puts "Creating Keys..."
key1 = Key.create!(room: room1, user: user1)  # user1が第1部室の鍵を持つ
# パターン1: 1人が複数の部屋の鍵を持つ
key2 = Key.create!(room: room1, user: user2)  # user2が第1部室の鍵を持つ
key3 = Key.create!(room: room2, user: user2)  # user2が第2部室の鍵も持つ
# パターン2: 複数人が同じ部屋の鍵を持つ
key4 = Key.create!(room: room3, user: user3)  # user3も第3部室の鍵を持つ
key5 = Key.create!(room: room3, user: user4)  # user4も第3部室の鍵を持つ

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
puts "  - #{Key.count} keys"
puts "  - #{KeyTransferLog.count} transfer logs"
