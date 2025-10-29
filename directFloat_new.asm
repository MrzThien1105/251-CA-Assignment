# -----------------------------------------------------------------------------
# MIPS Program: Read and Parse Floating-Point Numbers from a Large File
#
# Description:
# This program reads a text file ("input.txt") containing floating-point
# numbers with one decimal place, separated by spaces. It correctly handles
# large files (>4KB) by reading in chunks, parses the numbers into a float
# array, and then prints each number to the console on a new line.
#
# Syntax: Standard MIPS Assembly (one instruction per line).
# -----------------------------------------------------------------------------

.data
    input:      .asciiz "input.txt"

    # Use large buffers to safely handle large files.
    fileWords:  .space 16384       # Buffer for file content
    .align 2
    # Allocate space for ~2000 numbers to be safe.
    input_array: .space 8000        # Array for floats from input.txt

    newline:    .asciiz "\n"
    ten_float:  .float 10.0        # Constant 10.0 for division

.text
.globl main

main:
    # --- Set up arguments for the function call ---
    la $a0, input           # Arg 0: file name address
    la $a1, input_array     # Arg 1: array address
    jal inputFile           # Call the function
    
    # --- After function returns, prepare for printing ---
    # $v0 now holds the number of floats read.
    # We must save it because the print syscalls will overwrite $v0.
    move $s2, $v0           # Save float count in a saved register, $s2

    # Fall through to the printing section
    j print_floats
    

# -----------------------------------------------------------------
# FUNCTION: inputFile
# Reads a file and parses floats into an array.
# Arguments: $a0: Address of the file name string.
#            $a1: Address of the float array to fill.
# Returns:   $v0: The number of floats successfully read.
# -----------------------------------------------------------------
inputFile:
    # --- Function Prologue: Save registers that will be modified ---
    addi $sp, $sp, -24
    sw $ra, 20($sp)     # Save return address
    sw $s0, 16($sp)     # Save registers we will use
    sw $s1, 12($sp)
    sw $a0, 8($sp)      # Save original arguments
    sw $a1, 4($sp)

    # STAGE 1: OPEN FILE
    lw $a0, 8($sp)      # Restore file name argument for syscall
    li $v0, 13
    li $a1, 0
    li $a2, 0
    syscall
    move $s0, $v0       # Save file descriptor in $s0

    # STAGE 2: READ FILE IN CHUNKS
    li   $s1, 0
    la   $t0, fileWords
read_loop:
    li   $v0, 14
    move $a0, $s0
    move $a1, $t0
    li   $a2, 4096
    syscall
    beq  $v0, $zero, done_reading
    addu $s1, $s1, $v0
    addu $t0, $t0, $v0
    j    read_loop
done_reading:
    
    # STAGE 3: CLOSE FILE
    li $v0, 16
    move $a0, $s0
    syscall

    # STAGE 4: PARSE BUFFER
    li $t0, 0
    li $t1, 0  # $t1 is our array index / float counter
    li $t2, 0
    li $t3, 0
    li $t9, 0
    li $t5, 0
    li $t6, 0

parse_loop:
    beq $t0, $s1, store_last_number
    lb $t7, fileWords($t0)
    
    li $t8, 45
    beq $t7, $t8, set_neg
    
    li $t8, 32
    beq $t7, $t8, store_number
    
    li $t8, 10
    beq $t7, $t8, store_number
    
    li $t8, 46
    beq $t7, $t8, set_decimal
    
    li $t8, 48
    li $t4, 57
    blt $t7, $t8, next_char_parse
    bgt $t7, $t4, next_char_parse
    
    sub $t7, $t7, $t8
    beq $t6, 0, accumulate_int
    move $t3, $t7
    li $t6, 2
    j next_char_parse

accumulate_int:
    mul $t2, $t2, 10
    add $t2, $t2, $t7
    li $t5, 1
    
next_char_parse:
    addi $t0, $t0, 1
    j parse_loop

set_neg:
    li $t9, 1
    addi $t0, $t0, 1
    j parse_loop

set_decimal:
    li $t6, 1
    addi $t0, $t0, 1
    j parse_loop

store_number:
    beq $t5, 0, skip_store
    
    beq $t6, 0, no_decimal
    mul $t2, $t2, 10
    add $t2, $t2, $t3
    j after_decimal
no_decimal:
    mul $t2, $t2, 10
after_decimal:

    beq $t9, 0, store_val
    neg $t2, $t2
store_val:
    mtc1 $t2, $f0
    cvt.s.w $f0, $f0
    l.s $f1, ten_float
    div.s $f0, $f0, $f1
    
    sll $t7, $t1, 2
    lw $t8, 4($sp)      # Get array base address from stack
    add $t8, $t8, $t7
    s.s $f0, 0($t8)
    
    addi $t1, $t1, 1
    li $t2, 0
    li $t3, 0
    li $t5, 0
    li $t6, 0
    li $t9, 0
    
skip_store:
    addi $t0, $t0, 1
    j parse_loop

# STAGE 5: HANDLE THE LAST NUMBER
store_last_number:
    beq $t5, 0, exit_inputFile # If no pending number, jump to function exit

    # Logic to store the final number
    beq $t6, 0, no_decimal_last
    mul $t2, $t2, 10
    add $t2, $t2, $t3
    j after_decimal_last
no_decimal_last:
    mul $t2, $t2, 10
after_decimal_last:

    beq $t9, 0, store_val_last
    neg $t2, $t2
store_val_last:
    mtc1 $t2, $f0
    cvt.s.w $f0, $f0
    l.s $f1, ten_float
    div.s $f0, $f0, $f1
    
    sll $t7, $t1, 2
    lw $t8, 4($sp)      # Use LW to load the array base address
    add $t8, $t8, $t7
    s.s $f0, 0($t8)
    
    addi $t1, $t1, 1    # Increment the final count

# --- Function Epilogue: Prepare return value and restore stack ---
exit_inputFile:
    move $v0, $t1       # Set the return value to the number of floats found

    # Restore saved registers and stack pointer
    lw $ra, 20($sp)
    lw $s0, 16($sp)
    lw $s1, 12($sp)
    lw $a0, 8($sp)
    lw $a1, 4($sp)
    addi $sp, $sp, 24
    
    jr $ra              # Return to the caller (main)

# -----------------------------------------------------------------
# STAGE 6: PRINT THE FLOATS FROM THE ARRAY
# -----------------------------------------------------------------
print_floats:
    li $t3, 0           # Loop counter i = 0

print_loop:
    bge $t3, $s2, exit  # Use the saved count in $s2 as the loop limit

    # Calculate address of input_array[i]
    sll $t7, $t3, 2
    la $t8, input_array 
    add $t8, $t8, $t7
    lwc1 $f12, 0($t8)   # Load float into $f12 for printing

    li $v0, 2
    syscall             # Print float
    
    li $v0, 4
    la $a0, newline
    syscall             # Print newline

    addi $t3, $t3, 1    # i++
    j print_loop

exit:
    li $v0, 10
    syscall