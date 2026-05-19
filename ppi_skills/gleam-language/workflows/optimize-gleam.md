# Workflow: Optimize Gleam Performance

<process>
## Step 1: Measure First

Don't optimize blindly. Use benchmarking tools:

```bash
gleam add gleamy_bench --dev  # or glychee for Elixir's Benchee
```

## Step 2: Common Optimizations

### List Operations
```gleam
// BAD: O(n) prepend in a loop
list.fold(items, [], fn(acc, item) { [item, ..acc] })

// GOOD: Build reversed, then reverse once
list.fold(items, [], fn(acc, item) { [item, ..acc] })
|> list.reverse
```

### String Concatenation
```gleam
// BAD: O(n²) string concatenation
list.fold(strings, "", fn(acc, s) { acc <> s })

// GOOD: Use string_builder or io
list.map(strings, string.to_bits)
|> bits_builder.from_bit_arrays
|> bits_builder.to_string
```

### Tail Recursion
Gleam on Erlang optimizes tail calls. On JS, use `list` stdlib functions instead of manual recursion where possible.

## Step 3: Use Appropriate Data Structures

- `List`: sequential access, prepend
- `Dict`: key-value lookup (Erlang map)
- `Set`: membership testing
- `BitArray`: binary data

## Step 4: Profile on Target

Erlang and JS have different performance characteristics. Profile on your actual target runtime.
</process>
