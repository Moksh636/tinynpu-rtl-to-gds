#!/usr/bin/env python3

from __future__ import annotations

import argparse
import random
from pathlib import Path
from typing import Iterable

from golden_model import matmul_4x4_int8

N = 4
INT8_MIN = -128
INT8_MAX = 127


def normalize_matrix(matrix: object) -> list[list[int]]:
    if hasattr(matrix, "tolist"):
        matrix = matrix.tolist()

    rows = [[int(value) for value in row] for row in matrix]

    if len(rows) != N or any(len(row) != N for row in rows):
        raise ValueError(f"Expected a {N}x{N} matrix")

    return rows


def flatten(matrix: Iterable[Iterable[int]]) -> list[int]:
    return [int(value) for row in matrix for value in row]


def random_matrix(rng: random.Random) -> list[list[int]]:
    return [
        [rng.randint(INT8_MIN, INT8_MAX) for _ in range(N)]
        for _ in range(N)
    ]


def directed_cases() -> list[tuple[list[list[int]], list[list[int]]]]:
    zeros = [[0 for _ in range(N)] for _ in range(N)]

    identity = [
        [1 if row == column else 0 for column in range(N)]
        for row in range(N)
    ]

    pattern = [
        [1, 2, 3, 4],
        [-1, -2, -3, -4],
        [10, 0, -10, 5],
        [127, -128, 1, -1],
    ]

    all_max = [[127 for _ in range(N)] for _ in range(N)]
    all_ones = [[1 for _ in range(N)] for _ in range(N)]

    alternating = [
        [-128 if (row + column) % 2 == 0 else 127 for column in range(N)]
        for row in range(N)
    ]

    checker = [
        [1 if (row + column) % 2 == 0 else -1 for column in range(N)]
        for row in range(N)
    ]

    return [
        (zeros, zeros),
        (identity, pattern),
        (pattern, identity),
        (all_max, all_ones),
        (alternating, checker),
    ]


def write_line(output_file, values: Iterable[int]) -> None:
    output_file.write(" ".join(str(value) for value in values))
    output_file.write("\n")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate deterministic TinyNPU verification vectors."
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
        help="Output vector-file path.",
    )
    parser.add_argument(
        "--random-cases",
        type=int,
        default=25,
        help="Number of randomized matrix pairs.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=20260711,
        help="Deterministic random seed.",
    )
    args = parser.parse_args()

    if args.random_cases < 0:
        raise ValueError("--random-cases cannot be negative")

    rng = random.Random(args.seed)

    cases = directed_cases()

    for _ in range(args.random_cases):
        cases.append((random_matrix(rng), random_matrix(rng)))

    args.output.parent.mkdir(parents=True, exist_ok=True)

    with args.output.open("w", encoding="utf-8") as output_file:
        output_file.write(f"{len(cases)}\n")

        for matrix_a, matrix_b in cases:
            expected = normalize_matrix(
                matmul_4x4_int8(matrix_a, matrix_b)
            )

            write_line(output_file, flatten(matrix_a))
            write_line(output_file, flatten(matrix_b))
            write_line(output_file, flatten(expected))

    print(
        f"Generated {len(cases)} cases "
        f"({len(directed_cases())} directed + "
        f"{args.random_cases} randomized) "
        f"with seed {args.seed}"
    )
    print(f"Vector file: {args.output}")


if __name__ == "__main__":
    main()
