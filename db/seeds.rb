# Clear existing data
puts "Cleaning up database..."
Reservation.delete_all
User.delete_all

# Create Users
puts "Creating Users..."
user1 = User.create!(id: 1)
user2 = User.create!(id: 2)

# Create Reservations
puts "Creating Reservations..."
now = Time.current

# 1. Past Reservation (Yesterday)
Reservation.create!(
  user: user1,
  start_at: now.yesterday.change(hour: 10, min: 0),
  end_at: now.yesterday.change(hour: 12, min: 0)
)

# 2. Today's Reservation
Reservation.create!(
  user: user2,
  start_at: now.change(hour: 13, min: 0),
  end_at: now.change(hour: 15, min: 0)
)

# 3. Future Reservation (Tomorrow)
Reservation.create!(
  user: user1,
  start_at: now.tomorrow.change(hour: 10, min: 0),
  end_at: now.tomorrow.change(hour: 12, min: 0)
)

puts "Done! Created #{User.count} users and #{Reservation.count} reservations."
