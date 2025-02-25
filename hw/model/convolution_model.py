"""Convolution model implementation."""

import numpy as np
from scipy import signal


def convolution(input, kernel, stride):
    """Perform 2D convolution with kernel reversal and stride control."""
    kernel = kernel[::-1, ::-1]  # Flip kernel for proper convolution
    result = signal.convolve2d(input, kernel, mode="valid")
    return result[::stride, ::stride]


def print_matrix(name, matrix):
    """Print a labeled matrix for debugging."""
    print()
    print(f"{name}:")
    print(matrix)


if __name__ == "__main__":
    input_size = 6
    kernel_size = 3
    stride = 1

    kernel = np.arange(kernel_size * kernel_size).reshape((kernel_size, kernel_size))
    input = np.arange(input_size * input_size).reshape((input_size, input_size))

    result = convolution(input, kernel, stride)

    print_matrix("Kernel", kernel)
    print_matrix("Input", input)
    print_matrix("Result", result)