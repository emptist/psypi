import gleam/int


/// Bitwise AND operation (test)
pub fn and(x: Int, y: Int) -> Int {
  int.bitwise_and(x, y)
}

/// Bitwise OR
pub fn or(x: Int, y: Int) -> Int {
  int.bitwise_or(x, y)
}

/// Bitwise XOR
pub fn xor(x: Int, y: Int) -> Int {
  int.bitwise_exclusive_or(x, y)
}

/// Bitwise NOT (one's complement)
pub fn not(x: Int) -> Int {
  int.bitwise_not(x)
}

/// Left shift
pub fn shift_left(x: Int, bits: Int) -> Int {
  int.bitwise_shift_left(x, bits)
}

/// Right shift
pub fn shift_right(x: Int, bits: Int) -> Int {
  int.bitwise_shift_right(x, bits)
}
