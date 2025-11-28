# ASCII Number Separator - Architecture Design

## Overview

This module parses UART packet payloads containing space-separated integers in ASCII format, converts them to int32 values, and stores them in RAM for subsequent processing.

### Input Format
- ASCII string with space-separated integers, e.g., "123 -456 789"
- Valid characters: digits (0-9), space (0x20), minus sign (0x2D)
- Maximum 2048 integers per packet
- Each UART packet contains a complete sequence

### Module Hierarchy

```
ascii_num_sep_top
├── ascii_validator
├── char_stream_parser
├── ascii_to_int32
├── data_write_controller
└── num_storage_ram
```

## Module 1: ascii_validator

### Purpose
Validates all characters in the payload stream before processing begins.

### Interface
```systemverilog
module ascii_validator (
    input  logic        clk,
    input  logic        rst_n,
    
    // Input from uart_packet_handler
    input  logic [7:0]  payload_data,
    input  logic        payload_valid,
    input  logic        payload_last,
    output logic        payload_ready,
    
    // Output status
    output logic        done,
    output logic        invalid      // 1: found invalid char
);
```

### Functionality
- Accepts payload stream via AXI-Stream-like interface
- Checks each byte: valid if (0x30-0x39) OR (0x20) OR (0x2D)
- Asserts `done` when `payload_last` is received
- Asserts `invalid` if any invalid character detected
- **Critical**: Must buffer all data for downstream modules

### State Machine
```
IDLE -> VALIDATE -> DONE
```

## Module 2: char_stream_parser

### Purpose
Parses validated character stream, identifies number boundaries, and controls ascii_to_int32 converter.

### Interface
```systemverilog
module char_stream_parser (
    input  logic        clk,
    input  logic        rst_n,
    
    // Control input
    input  logic        start,           // from validator.done && !invalid
    input  logic [15:0] total_length,
    
    // Character buffer read interface
    output logic [15:0] char_addr,
    input  logic [7:0]  char_data,
    
    // Control to ascii_to_int32
    output logic        num_start,       // start new number
    output logic [7:0]  num_char,
    output logic        num_valid,       // valid digit/minus
    output logic        num_end,         // number complete
    
    // Status
    output logic [10:0] num_count,       // total numbers parsed
    output logic        parse_done
);
```

### Functionality
- Reads characters from validator's buffer
- Identifies number boundaries (space = separator)
- Generates control signals for ascii_to_int32:
  - `num_start`: first char of a number
  - `num_valid`: each digit or minus sign
  - `num_end`: space or end of stream
- Tracks total number count

### State Machine
```
IDLE -> PARSE_CHAR -> WAIT_CONVERT -> NEXT_CHAR -> DONE
```

### Key Logic
- Space detection: end current number if in-number state
- Consecutive spaces: skip without starting new number
- Minus sign: only valid at number start

## Module 3: ascii_to_int32

### Purpose
Converts ASCII digit stream to signed 32-bit integer.

### Interface
```systemverilog
module ascii_to_int32 (
    input  logic        clk,
    input  logic        rst_n,
    
    // Control interface
    input  logic        start,           // begin new number
    input  logic [7:0]  char_in,
    input  logic        char_valid,
    input  logic        num_end,         // end of current number
    
    // Output
    output logic signed [31:0] result,
    output logic        result_valid
);
```

### Functionality
- Accumulates digits: `result = result * 10 + (char - 0x30)`
- Handles negative numbers via sign flag
- Outputs result when `num_end` is asserted

### State Machine
```
IDLE -> ACCUMULATE -> OUTPUT
```

### Critical Logic
```verilog
if (char == 0x2D) begin  // minus sign
    is_negative <= 1;
end else if (char >= 0x30 && char <= 0x39) begin
    result <= result * 10 + (char - 8'd48);
end

// On num_end:
if (is_negative) result <= -result;
```

## Module 4: data_write_controller

### Purpose
Manages RAM write operations and address generation.

### Interface
```systemverilog
module data_write_controller (
    input  logic        clk,
    input  logic        rst_n,
    
    // Data input from ascii_to_int32
    input  logic signed [31:0] data_in,
    input  logic        data_valid,
    
    // Expected count
    input  logic [10:0] total_count,
    input  logic        parse_done,
    
    // RAM write interface
    output logic        ram_wr_en,
    output logic [10:0] ram_wr_addr,
    output logic [31:0] ram_wr_data,
    
    // Status
    output logic [10:0] write_count,
    output logic        all_done
);
```

### Functionality
- Receives converted int32 values
- Generates sequential write addresses
- Asserts `all_done` when `write_count == total_count`

### Logic
```verilog
always_ff @(posedge clk) begin
    if (data_valid) begin
        ram_wr_addr <= ram_wr_addr + 1;
        write_count <= write_count + 1;
    end
end

assign all_done = parse_done && (write_count == total_count);
```

## Module 5: num_storage_ram

### Purpose
Dual-port RAM for storing converted integers.

### Interface
```systemverilog
module num_storage_ram (
    input  logic        clk,
    input  logic        rst_n,
    
    // Write port
    input  logic        wr_en,
    input  logic [10:0] wr_addr,
    input  logic [31:0] wr_data,
    
    // Read port
    input  logic [10:0] rd_addr,
    output logic [31:0] rd_data
);
```

### Parameters
- DATA_WIDTH = 32
- DEPTH = 2048
- ADDR_WIDTH = 11

## Top-Level Integration: ascii_num_sep_top

### Interface
```systemverilog
module ascii_num_sep_top (
    input  logic        clk,
    input  logic        rst_n,
    
    // UART packet payload interface
    input  logic [7:0]  pkt_payload_data,
    input  logic        pkt_payload_valid,
    input  logic        pkt_payload_last,
    output logic        pkt_payload_ready,
    
    // RAM read interface for downstream
    input  logic [10:0] rd_addr,
    output logic [31:0] rd_data,
    
    // Status outputs
    output logic        processing,
    output logic        done,
    output logic        invalid,
    output logic [10:0] num_count
);
```

## Data Flow Diagram

```
UART Packet
    ↓
ascii_validator (buffering + validation)
    ↓ (if valid)
char_stream_parser (boundary detection)
    ↓
ascii_to_int32 (digit accumulation)
    ↓
data_write_controller (address management)
    ↓
num_storage_ram (storage)
    ↓
Downstream modules
```

## Timing Considerations

### Critical Paths
1. **Validator**: Must buffer entire payload before parser starts
2. **Parser → Converter**: Single-cycle control signals
3. **Converter**: Multi-cycle multiplication (result * 10)
4. **Write Controller**: Direct write-through

### Pipeline Stages
- Stage 1: Validation (N cycles, N = payload length)
- Stage 2: Parsing + Conversion (N cycles)
- Stage 3: Writing (0 cycles, concurrent with conversion)

## Error Handling

### Invalid Character Detection
- Validator sets `invalid` flag
- Parser does not start if `invalid == 1`
- Entire packet discarded

### Edge Cases
1. Empty payload: `num_count = 0`
2. Leading/trailing spaces: handled by parser state machine
3. Multiple consecutive spaces: skip without error
4. Minus sign in middle: treated as invalid (caught by validator)
5. Overflow: no explicit handling (user responsibility)

## Resource Estimation

- **LUTs**: ~500 (state machines + comparators)
- **FFs**: ~200 (registers + counters)
- **BRAM**: 1 block (2048x32 = 64Kbit)
- **DSP**: 1 (for multiplication in ascii_to_int32)

## Testing Strategy

### Unit Tests
1. **ascii_validator_tb**: Test valid/invalid character detection
2. **char_stream_parser_tb**: Test boundary detection
3. **ascii_to_int32_tb**: Test conversion accuracy
4. **data_write_controller_tb**: Test address generation
5. **num_storage_ram_tb**: Test RAM read/write

### Integration Test
- **ascii_num_sep_top_tb**: End-to-end test with various inputs
  - Positive numbers only
  - Negative numbers
  - Mixed positive/negative
  - Edge cases (empty, max length)

## Implementation Notes

### Code Style
- All comments in English
- Use SystemVerilog features (logic, always_ff, always_comb)
- Parameterize widths where applicable
- Follow project naming conventions

### Signal Naming
- `_valid`: indicates data validity
- `_ready`: indicates readiness to accept data
- `_done`: indicates completion
- `_en`: enable signal
- Avoid overly generic names

### Reset Strategy
- Asynchronous active-low reset (`rst_n`)
- All sequential elements reset to known state
- Combinational outputs don't require reset
