#!/usr/bin/env python3

from typing import List
import random

Matrix4x4 = List[List[int]]


def check_int8(value: int) -> None:
    if value < -128 or value > 127:
        raise ValueError(f"Value {value} is outside signed INT8 range")


def matmul_4x4_int8(a: Matrix4x4, b: Matrix4x4) -> Matrix4x4:
    """
    Computes C = A x B.

    A and B:
        4x4 signed INT8 matrices

    C:
        4x4 signed INT32-style Python integer matrix
    """
    if len(a) != 4 or len(b) != 4:
        raise ValueError("A and B must be 4x4 matrices")

    for row in a:
        if len(row) != 4:
            raise ValueError("A must be 4x4")
        for value in row:
            check_int8(value)

    for row in b:
        if len(row) != 4:
            raise ValueError("B must be 4x4")
        for value in row:
            check_int8(value)

    c = [[0 for _ in range(4)] for _ in range(4)]

    for i in range(4):
        for j in range(4):
            acc = 0
            for k in range(4):
                acc += a[i][k] * b[k][j]
            c[i][j] = acc

    return c


def flatten_4x4(matrix: Matrix4x4) -> List[int]:
    return [matrix[i][j] for i in range(4) for j in range(4)]


def random_int8_matrix(seed: int | None = None) -> Matrix4x4:
    rng = random.Random(seed)
    return [[rng.randint(-128, 127) for _ in range(4)] for _ in range(4)]


def main() -> None:
    a = [
        [1, 2, 3, 4],
        [5, 6, 7, 8],
        [-1, -2, -3, -4],
        [10, 0, -10, 2],
    ]

    b = [
        [1, 0, 2, -1],
        [0, 1, 3, 2],
        [4, -2, 0, 1],
        [-3, 5, 1, 0],
    ]

    c = matmul_4x4_int8(a, b)

    print("A =")
    for row in a:
        print(row)

    print("\nB =")
    for row in b:
        print(row)

    print("\nC = A x B")
    for row in c:
        print(row)

    print("\nFlattened C:")
    print(flatten_4x4(c))


if __name__ == "__main__":
    main()
