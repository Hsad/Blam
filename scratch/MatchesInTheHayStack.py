
import random

def generate_sorted_columns(rows, min_value, max_value):
    column1 = [random.randint(min_value, max_value) for _ in range(rows)]
    column2 = [random.randint(min_value, max_value) for _ in range(rows)]
    column1.sort()
    column2.sort()
    return column1, column2

rows = 10
min_value = 1
max_value = 500

column1, column2 = generate_sorted_columns(rows, min_value, max_value)
print("Column 1 (sorted):", column1)
print("Column 2 (sorted):", column2)

c3 = [max(c1, c2) for c1,c2 in zip(column1, column2)]

print("Column 3 (sorted):", c3)
