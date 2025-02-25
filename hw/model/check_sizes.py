"""Utility to check valid input sizes for CNN operations given parameters."""

def check_sizes(min_size, max_size):
    """Check and print valid input sizes that produce clean output dimensions."""
    kernel = 3
    stride = 1
    pool = 2
    
    print(f"Valid sizes (min={min_size}, max={max_size}):")
    print("Input -> Conv -> Output")
    print("-----------------------")
    
    for input_size in range(min_size, max_size + 1):
        # Check convolution
        conv_size = (input_size - kernel) / stride + 1
        if not conv_size.is_integer():
            continue
            
        conv_size = int(conv_size)
        
        # Check pooling
        if conv_size % pool != 0:
            continue
            
        output_size = conv_size // pool
        print(f"{input_size:2d} -> {conv_size:2d} -> {output_size:2d}")


if __name__ == "__main__":
    min_size = int(input("Enter minimum size: "))
    max_size = int(input("Enter maximum size: "))
    check_sizes(min_size, max_size)