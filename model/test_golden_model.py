import pytest

from golden_model import matmul_4x4_int8, flatten_4x4, random_int8_matrix


def test_known_matrix_multiply():
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

    expected = [
        [1, 16, 12, 6],
        [9, 32, 36, 14],
        [-1, -16, -12, -6],
        [-36, 30, 22, -20],
    ]

    assert matmul_4x4_int8(a, b) == expected


def test_flatten_4x4():
    m = [
        [1, 2, 3, 4],
        [5, 6, 7, 8],
        [9, 10, 11, 12],
        [13, 14, 15, 16],
    ]

    assert flatten_4x4(m) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]


def test_random_matrix_shape():
    m = random_int8_matrix(seed=123)

    assert len(m) == 4
    for row in m:
        assert len(row) == 4
        for value in row:
            assert -128 <= value <= 127


def test_rejects_out_of_range_int8():
    a = [
        [1, 2, 3, 4],
        [5, 6, 7, 8],
        [9, 10, 11, 12],
        [13, 14, 15, 200],
    ]

    b = [
        [1, 0, 2, -1],
        [0, 1, 3, 2],
        [4, -2, 0, 1],
        [-3, 5, 1, 0],
    ]

    with pytest.raises(ValueError):
        matmul_4x4_int8(a, b)
