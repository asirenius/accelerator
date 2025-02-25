"""Main CNN behavioral model implementing convolution, ReLU, and pooling operations."""

import numpy as np
from skimage.measure import block_reduce

from fixed_point_model import float_to_fixed_point
from convolution_model import convolution


def convert_array_to_fixed_point(array, int_bits=3, frac_bits=12):
    """Convert floating-point numpy array to fixed-point representation."""
    shape = array.shape
    fp_list = []
    for value in array.flatten():
        fp_list.append(float_to_fixed_point(value, int_bits, frac_bits))
    return np.reshape(fp_list, shape)


def print_comparison(name, float_array, fixed_array):
    """Print comparison between floating-point and fixed-point representations."""
    print(f'===============\n{name}\n===============')
    print('\nFloat values\n------------------')
    print(float_array)
    print('\nFixed-point values\n------------------')
    print(fixed_array)
    print()


def generate_basic_data(input_size=(6,6), kernel_size=(3,3)):
    """Generate sequential test data for CNN operations."""
    kernel = np.arange(kernel_size[0] * kernel_size[1]).reshape(kernel_size)
    input_data = np.arange(input_size[0] * input_size[1]).reshape(input_size)
    return input_data, kernel


def generate_random_data(input_size=(6,6), kernel_size=(3,3), random_seed=5):
    """Generate random test data for CNN operations."""
    np.random.seed(random_seed)
    values = np.random.uniform(-1, 1, input_size[0] * input_size[1]).reshape(input_size)
    weights = np.random.uniform(-1, 1, kernel_size[0] * kernel_size[1]).reshape(kernel_size)
    return values, weights


def process_cnn_layers(input_data, weights, stride=1):
    """Process CNN layers with convolution, ReLU, and pooling."""
    # Convolution
    conv_output = convolution(input_data, weights, stride)
    
    # ReLU activation
    relu_output = np.maximum(conv_output, 0)
    
    # Max pooling (2x2)
    pooled_output = block_reduce(relu_output, (2,2), np.max)
    
    return conv_output, relu_output, pooled_output


def main(use_basic=True):
    """Run the CNN model with either basic or random test data."""
    INT_BITS = 3
    FRAC_BITS = 12

    INPUT_SIZE = 6
    KERNEL_SIZE = 3
    STRIDE = 1
    
    if use_basic:
        values, weights = generate_basic_data((INPUT_SIZE, INPUT_SIZE), (KERNEL_SIZE, KERNEL_SIZE))
    else:
        values, weights = generate_random_data((INPUT_SIZE, INPUT_SIZE), (KERNEL_SIZE, KERNEL_SIZE))
    
    # Process CNN layers
    conv_output, relu_output, pooled_output = process_cnn_layers(values, weights, STRIDE)
    
    # Convert to fixed point
    values_fp = convert_array_to_fixed_point(values, INT_BITS, FRAC_BITS)
    weights_fp = convert_array_to_fixed_point(weights, INT_BITS, FRAC_BITS)
    conv_fp = convert_array_to_fixed_point(conv_output, INT_BITS, FRAC_BITS)
    relu_fp = convert_array_to_fixed_point(relu_output, INT_BITS, FRAC_BITS)
    pool_fp = convert_array_to_fixed_point(pooled_output, INT_BITS, FRAC_BITS)
    
    # Print results
    print_comparison("Input Values", values, values_fp)
    print_comparison("Weights", weights, weights_fp)
    print_comparison("Convolution Output", conv_output, conv_fp)
    print_comparison("ReLU Output", relu_output, relu_fp)
    print_comparison("Pooling Output", pooled_output, pool_fp)


if __name__ == "__main__":
    main(use_basic=True)