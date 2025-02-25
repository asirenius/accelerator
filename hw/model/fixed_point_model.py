"""Fixed-point arithmetic implementation."""

def twos_complement(binary_str, total_bits):
    """Convert a binary string to its two's complement representation."""
    inverted = ''.join('1' if bit == '0' else '0' for bit in binary_str)
    value = int(inverted, 2) + 1
    return format(value, f'0{total_bits}b')

def float_to_fixed_point(number, int_bits, frac_bits):
    """Convert a floating-point number to fixed-point binary representation."""
    is_negative = number < 0
    abs_number = abs(number)

    # Integer part
    int_part = int(abs_number)
    int_binary = format(int_part, f'0{int_bits}b')

    # Fractional part
    frac_value = abs_number - int_part
    frac_bits_list = []
    for _ in range(frac_bits):
        frac_value *= 2
        bit = int(frac_value)
        frac_bits_list.append(str(bit))
        frac_value -= bit
    frac_binary = ''.join(frac_bits_list)

    # Combine
    full_binary = int_binary + frac_binary

    if is_negative:
        return f"1{twos_complement(full_binary, int_bits + frac_bits)}"
    else:
        return f"0{full_binary}"
    
def fixed_point_to_float(binary_str, int_bits, frac_bits):
    """Convert a fixed-point binary string to floating-point representation."""
    is_negative = binary_str[0] == '1'
    magnitude_bits = binary_str[1:]
    
    # Handle two's complement for negative numbers
    if is_negative:
        magnitude_bits = twos_complement(magnitude_bits, int_bits + frac_bits)
    
    # Convert to float
    value = 0.0

    # Process integer bits
    for i in range(int_bits):
        value += int(magnitude_bits[i]) * (2 ** (int_bits - 1 - i))
    
    # Process fractional bits
    for i in range(frac_bits):
        value += int(magnitude_bits[int_bits + i]) * (2 ** -(i + 1))
    
    return -value if is_negative else value


if __name__ == "__main__":
    # Test the fixed-point conversion functions
    print("Testing twos complement:", twos_complement('0110011110110110', 3 + 12))
    print("Positive float to fixed point:", float_to_fixed_point(2.356, 3, 12))
    print("Negative float to fixed point:", float_to_fixed_point(-2.356, 3, 12))
    print("Fixed point to float:", fixed_point_to_float('0010110111111011',3,12))
    print("Negative fixed point to float:", fixed_point_to_float('1101101001001110',3,12))
    print("Round-trip conversion:", fixed_point_to_float(float_to_fixed_point(-2.729, 3, 12), 3, 12))