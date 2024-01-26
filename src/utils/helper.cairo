/// Raise a number to a power.
/// * `base` - The number to raise.
/// * `exp` - The exponent.
/// # Returns
/// * `u256` - The result of base raised to the power of exp.
fn pow(base: u256, exp: u256) -> u256 {
    if exp == 0 {
        1
    } else if exp == 1 {
        base
    } else if (exp & 1) == 1 {
        base * pow(base * base, exp / 2)
    } else {
        pow(base * base, exp / 2)
    }
}
