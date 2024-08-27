#!/usr/bin/env python3
# This script groups elements in a JSON array into given number of batches
# Usage example: cat data.json | python .github/scripts/batcher.py 10
# The JSON array is expected to be passed from stdin
# The output will be an array of comma-separated-values to stdout

import sys
import json

def batch_array(arr, n):
    if n <= 0:
        raise ValueError("n must be a positive integer")

    batch_size = len(arr) // n
    remainder = len(arr) % n
    
    batched_array = []
    start_index = 0
    
    for i in range(n):
        end_index = start_index + batch_size + (1 if i < remainder else 0)
        batched_array.append(arr[start_index:end_index])
        start_index = end_index
        
    return batched_array


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: cat data.json | python3 {sys.argv[0]} <batch_count>", file=sys.stderr)
        sys.exit(1)

    n_batches = int(sys.argv[1])
    arr = json.load(sys.stdin)
    output = batch_array(arr, n_batches)
    json.dump([','.join(batch) for batch in output], sys.stdout, indent=2)