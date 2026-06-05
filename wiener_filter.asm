.data
# --- Thong tin File ---
input_file:   .asciiz "input.txt"      # Ten file chua tin hieu dau vao
desired_file: .asciiz "desired.txt"    # Ten file chua tin hieu mong muon
output_file:  .asciiz "output.txt"     # Ten file de ghi ket qua

# --- Vung nho luu tru du lieu ---
NUM_SAMPLES: .word 10                  # So luong mau (cap nhat khi doc file)
desired_signal: .space 400             # Mang chua tin hieu mong muon
input_signal: .space 400               # Mang chua tin hieu dau vao (max 100 float)
optimize_coefficient: .space 400       # He so bo loc Wiener
output_signal:        .space 400       # Mang ket qua sau khi loc
crosscorr:    .space 400               # Mang luu ket qua tuong quan cheo
autocorr:     .space 400               # Mang luu ket qua tu tuong quan
R:            .space 4000              # Ma tran Toeplitz (R)

# --- Bo dem doc file ---
buf_size:     .word 10240              # Kich thuoc bo dem (10KB)
buffer:       .space 10240             # Vung nho dem

# --- Bien so ---
mmse:         .float 0.0               # Bien luu gia tri MMSE

# --- Cac hang so (Float) ---
zero_f:       .float 0.0
one_f:        .float 1.0
ten:          .float 10.0
half:         .float 0.5
minus_half:   .float -0.5
EPSILON:      .float 1.0e-12           # Gia tri nho dung de so sanh

# --- Cac chuoi thong bao ---
header_filtered: .asciiz "Filtered output: "
header_mmse:     .asciiz "\nMMSE: "
space_str:       .asciiz " "
str_buf:         .space 32             # Bo dem de chuyen float sang chuoi
error_size:      .asciiz "Error: size not match\n"
singular:        .asciiz "Warning: matrix nearly singular in solveLinearSystem\n"
newline:         .asciiz "\n"

# --- Do dai chuoi ---
LEN_HEADER_FILTERED: .word 17
LEN_HEADER_MMSE:     .word 7
LEN_ERROR_SIZE:      .word 22

.text
.globl main

# =========================================================
# CHUONG TRINH CHINH (MAIN)
# =========================================================
main:
    # -----------------------------------------------------
    # BUOC 1: DOC DU LIEU TU FILE VAO MANG
    # -----------------------------------------------------
    
    # 1.1 Doc file input.txt
    la $a0, input_file
    la $a1, input_signal
    lw $a2, NUM_SAMPLES
    jal read_file_to_array
    move $s0, $v0            # s0 = So luong mau input
    
    bltz $s0, exit_prog      # Loi -> Thoat

    # 1.2 Doc file desired.txt
    la $a0, desired_file
    la $a1, desired_signal
    lw $a2, NUM_SAMPLES
    jal read_file_to_array
    move $s1, $v0            # s1 = So luong mau desired
    
    bltz $s1, exit_prog      # Loi -> Thoat

    # 1.3 Kiem tra kich thuoc hai file
    bne $s0, $s1, size_error

    # -----------------------------------------------------
    # BUOC 2: TINH TOAN BO LOC WIENER
    # -----------------------------------------------------
    
    # Nap cac hang so float
    l.s $f1, ten             
    l.s $f2, half            
    l.s $f4, minus_half      

    # 2.1 Tinh he so bo loc
    la $a0, desired_signal
    la $a1, input_signal
    la $a2, optimize_coefficient
    lw $a3, NUM_SAMPLES
    jal computeWienerCoefficients

    # 2.2 Ap dung bo loc
    la $a0, input_signal
    la $a1, optimize_coefficient
    la $a2, output_signal
    lw $a3, NUM_SAMPLES
    jal applyWienerFilter
    
    # 2.3 Tinh sai so MMSE
    la $a0, desired_signal
    la $a1, output_signal
    lw $a2, NUM_SAMPLES
    la $a3, mmse
    jal compute_mmse

    # -----------------------------------------------------
    # BUOC 3: XUAT KET QUA RA TERMINAL VA FILE
    # -----------------------------------------------------

    # In ket qua ra man hinh (Da xu ly khoang trang thua)
    jal print_all_content

    # Mo file output.txt de ghi
    li $v0, 13
    la $a0, output_file
    li $a1, 1                # Write mode
    li $a2, 0
    syscall
    move $s0, $v0            # s0 = File Descriptor

    bltz $s0, exit_prog

    # Ghi tieu de "Filtered output: "
    li $v0, 15
    move $a0, $s0
    la $a1, header_filtered
    lw $a2, LEN_HEADER_FILTERED
    syscall

    # Vong lap ghi mang output
    la $s1, output_signal            # Con tro mang
    lw $s2, NUM_SAMPLES      # Tong so phan tu N
    li $s3, 0                # i = 0

file_loop:
    bge $s3, $s2, file_mmse_section

    l.s $f12, 0($s1)         # Load so float
    la $a0, str_buf
    li $a1, 1                # 1 chu so thap phan
    jal float_to_str         
    
    # Ghi so
    move $a2, $v0
    li $v0, 15
    move $a0, $s0
    la $a1, str_buf
    syscall

    # --- [FIX] Kiem tra phan tu cuoi de tranh dau cach thua ---
    addi $t8, $s2, -1             # t8 = N - 1
    beq $s3, $t8, skip_space_file # Neu i == N-1, bo qua in dau cach

    # Ghi dau cach " "
    li $v0, 15
    move $a0, $s0
    la $a1, space_str
    li $a2, 1
    syscall

skip_space_file:
    addi $s3, $s3, 1         # i++
    addi $s1, $s1, 4         # Next float
    j file_loop

file_mmse_section:
    # Ghi tieu de "\nMMSE: "
    li $v0, 15
    move $a0, $s0
    la $a1, header_mmse
    lw $a2, LEN_HEADER_MMSE
    syscall

    # Ghi gia tri MMSE
    la $t0, mmse
    l.s $f12, 0($t0)
    la $a0, str_buf
    li $a1, 1
    jal float_to_str
    
    move $a2, $v0
    li $v0, 15
    move $a0, $s0
    la $a1, str_buf
    syscall

    # Dong file
    li $v0, 16
    move $a0, $s0
    syscall

    j exit_prog

# ---------------------------------------------------------
# Xu ly loi & Thoat
# ---------------------------------------------------------
size_error:
    li $v0, 4
    la $a0, error_size
    syscall

    li $v0, 13
    la $a0, output_file
    li $a1, 1                # Write mode
    li $a2, 0
    syscall
    move $s0, $v0            # s0 = File Descriptor

    bltz $s0, exit_prog

    li $v0, 15
    move $a0, $s0
    la $a1, error_size
    lw $a2, LEN_ERROR_SIZE
    syscall

    li $v0, 16
    move $a0, $s0
    syscall

    j exit_prog

exit_prog:
    li $v0, 10
    syscall

# =========================================================
# MODULE: DOC FILE VA PARSE SO THUC
# =========================================================
read_file_to_array:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp) 
    sw $s1, 8($sp) 
    sw $s2, 12($sp)
    sw $s3, 16($sp)

    move $s2, $a1            # Mang dich
    li $s3, 0                # Dem so phan tu

    # Mo file
    li $v0, 13
    li $a1, 0
    li $a2, 0
    syscall
    move $s0, $v0
    
    bltz $s0, rfta_error

    # Doc file
    li $v0, 14
    move $a0, $s0
    la $a1, buffer
    lw $a2, buf_size
    syscall
    move $t0, $v0

    # Dong file
    li $v0, 16
    move $a0, $s0
    syscall

    # Null terminate
    la $s1, buffer
    add $t1, $s1, $t0
    sb $zero, 0($t1)

parse_loop:
    bge $s3, $a2, rfta_done
    
    move $a0, $s1
    jal parse_float 
    
    beqz $v1, rfta_done
    
    s.s $f0, 0($s2)
    addi $s2, $s2, 4
    addi $s3, $s3, 1
    
    move $s1, $v0
    j parse_loop

rfta_done:
    move $v0, $s3
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra

rfta_error:
    li $v0, -1
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra

# --- Parse Float Helper ---
parse_float:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    move $t0, $a0

skip_ws:
    lb $t1, 0($t0)
    beqz $t1, pf_fail
    beq $t1, 32, is_ws
    beq $t1, 10, is_ws
    beq $t1, 13, is_ws
    j check_sign
is_ws:
    addi $t0, $t0, 1
    j skip_ws

check_sign:
    li $t2, 0 
    lb $t1, 0($t0)
    bne $t1, '-', parse_nums
    li $t2, 1
    addi $t0, $t0, 1

parse_nums:
    mtc1 $zero, $f0
    cvt.s.w $f0, $f0
    l.s $f10, ten
    li $t3, 0

int_loop:
    lb $t1, 0($t0)
    blt $t1, '0', check_dot_char
    bgt $t1, '9', check_dot_char
    li $t3, 1
    mul.s $f0, $f0, $f10
    sub $t4, $t1, '0'
    mtc1 $t4, $f1
    cvt.s.w $f1, $f1
    add.s $f0, $f0, $f1
    addi $t0, $t0, 1
    j int_loop

check_dot_char:
    lb $t1, 0($t0)
    bne $t1, '.', pf_finish
    addi $t0, $t0, 1
    l.s $f2, one_f

frac_loop:
    lb $t1, 0($t0)
    blt $t1, '0', pf_finish
    bgt $t1, '9', pf_finish
    li $t3, 1
    mul.s $f2, $f2, $f10
    sub $t4, $t1, '0'
    mtc1 $t4, $f1
    cvt.s.w $f1, $f1
    div.s $f1, $f1, $f2
    add.s $f0, $f0, $f1
    addi $t0, $t0, 1
    j frac_loop

pf_finish:
    beqz $t3, pf_fail
    beqz $t2, pf_ok
    neg.s $f0, $f0
pf_ok:
    move $v0, $t0
    li $v1, 1
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
pf_fail:
    li $v1, 0
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# =========================================================
# LOGIC TINH TOAN BO LOC WIENER
# =========================================================

# ---------------------------------------------------------
# Ham: compute_mmse
# Cong thuc: MMSE = (1/N) * sum( (desired[i] - output[i])^2 )
# Input: $a0 = desired[], $a1 = output[], $a2 = N, $a3 = &mmse
# ---------------------------------------------------------
compute_mmse:
    mtc1 $a2, $f10
    cvt.s.w $f10, $f10      # Chuyen N sang float de chia trung binh
    l.s $f12, zero_f        # Khoi tao sum_error = 0.0
    li $t0, 0               # i = 0
mmse_loop:
    bge $t0, $a2, mmse_done # Neu i >= N thi ket thuc
    
    # Tinh dia chi mang
    sll $t1, $t0, 2
    add $t2, $a0, $t1       # &desired[i]
    l.s $f0, 0($t2)
    add $t3, $a1, $t1       # &output[i]
    l.s $f1, 0($t3)
    
    # Tinh binh phuong sai so
    sub.s $f2, $f0, $f1     # error = desired - output
    mul.s $f2, $f2, $f2     # error^2
    add.s $f12, $f12, $f2   # sum += error^2
    
    addi $t0, $t0, 1        # i++
    j mmse_loop
mmse_done:
    div.s $f12, $f12, $f10  # MMSE = sum / N
    s.s $f12, 0($a3)        # Luu ket qua vao bien mmse
    jr $ra

# ---------------------------------------------------------
# Ham: computeWienerCoefficients
# Quy trinh:
#   1. Tinh Autocorrelation (Rxx) cua input
#   2. Tinh Crosscorrelation (Rdx) giua desired va input
#   3. Tao ma tran Toeplitz R tu Autocorrelation
#   4. Giai he phuong trinh R * h = Rdx (dung Gauss-Jordan) de tim h
# ---------------------------------------------------------
computeWienerCoefficients:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    
    # Luu tham so vao thanh ghi S
    move $s0, $a0           # desired
    move $s1, $a1           # input
    move $s2, $a2           # coeff (output)
    move $s3, $a3           # N

    # 1. Tinh Autocorrelation
    move $a0, $s1           # input
    la $a1, autocorr        # output buffer
    move $a2, $s3           # N
    jal compute_autocorr

    # 2. Tinh Crosscorrelation
    move $a0, $s0           # desired
    move $a1, $s1           # input
    la $a2, crosscorr       # output buffer
    move $a3, $s3           # N
    jal compute_crosscorr

    # 3. Tao ma tran Toeplitz
    la $a0, autocorr
    la $a1, R               # Matrix R
    move $a2, $s3           # N
    jal create_toeplitz

    # 4. Giai he phuong trinh tuyen tinh
    la $a0, R               # Matrix A
    la $a1, crosscorr       # Vector b
    move $a2, $s2           # Vector x (ket qua coeff)
    move $a3, $s3           # N
    jal solveLinearSystem

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra

# ---------------------------------------------------------
# Ham: compute_autocorr
# Cong thuc: Rxx[k] = (1/N) * sum(x[n] * x[n-k])
# Input: $a0=input, $a1=output, $a2=N
# ---------------------------------------------------------
compute_autocorr:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    mtc1 $a2, $f10
    cvt.s.w $f10, $f10      # Chuyen N sang float
    li $t0, 0               # k = 0
loop_outer_auto:
    bge $t0, $a2, end_auto
    l.s $f12, zero_f        # sum = 0
    move $t1, $t0           # n = k
loop_inner_auto:
    bge $t1, $a2, calc_avg_auto
    
    # Tinh dia chi va load gia tri
    sll $t2, $t1, 2
    add $t3, $a0, $t2
    l.s $f0, 0($t3)         # input[n]
    
    sub $t4, $t1, $t0       # n-k
    sll $t4, $t4, 2
    add $t5, $a0, $t4
    l.s $f1, 0($t5)         # input[n-k]
    
    mul.s $f2, $f0, $f1
    add.s $f12, $f12, $f2   # sum += tich
    addi $t1, $t1, 1
    j loop_inner_auto
calc_avg_auto:
    div.s $f12, $f12, $f10  # chia cho N
    sll $t2, $t0, 2
    add $t3, $a1, $t2
    s.s $f12, 0($t3)        # Luu vao autocorr[k]
    addi $t0, $t0, 1
    j loop_outer_auto
end_auto:
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

# ---------------------------------------------------------
# Ham: compute_crosscorr
# Cong thuc: Rdx[k] = (1/N) * sum(d[n] * x[n-k])
# Input: $a0=desired, $a1=input, $a2=output, $a3=N
# ---------------------------------------------------------
compute_crosscorr:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    mtc1 $a3, $f10
    cvt.s.w $f10, $f10
    li $t0, 0               # k = 0
loop_outer_cross:
    bge $t0, $a3, end_cross
    l.s $f12, zero_f        # sum = 0
    move $t1, $t0           # n = k
loop_inner_cross:
    bge $t1, $a3, calc_avg_cross
    
    # Load desired[n]
    sll $t2, $t1, 2
    add $t3, $a0, $t2
    l.s $f0, 0($t3)
    
    # Load input[n-k]
    sub $t4, $t1, $t0
    sll $t4, $t4, 2
    add $t5, $a1, $t4
    l.s $f1, 0($t5)
    
    mul.s $f2, $f0, $f1
    add.s $f12, $f12, $f2
    addi $t1, $t1, 1
    j loop_inner_cross
calc_avg_cross:
    div.s $f12, $f12, $f10  # Chia cho N
    sll $t2, $t0, 2
    add $t3, $a2, $t2
    s.s $f12, 0($t3)        # Luu vao crosscorr[k]
    addi $t0, $t0, 1
    j loop_outer_cross
end_cross:
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

# --- Helper: create_toeplitz ---
create_toeplitz:
    li $t0, 0               # row i
loop_row:
    bge $t0, $a2, end_toeplitz
    li $t1, 0               # col j
loop_col:
    bge $t1, $a2, next_row
    sub $t3, $t0, $t1
    bgez $t3, get_val
    sub $t3, $0, $t3        # abs(i-j)
get_val:
    sll $t4, $t3, 2
    add $t5, $a0, $t4
    l.s $f0, 0($t5)         # Lay tu autocorr
    mul $t6, $t0, $a2
    add $t6, $t6, $t1
    sll $t6, $t6, 2
    add $t7, $a1, $t6
    s.s $f0, 0($t7)         # Luu vao Matrix R
    addi $t1, $t1, 1
    j loop_col
next_row:
    addi $t0, $t0, 1
    j loop_row
end_toeplitz:
    jr $ra

# ---------------------------------------------------------
# Ham: solveLinearSystem
# Muc dich: Giai he phuong trinh A * x = b bang phuong phap Gauss-Jordan
# Input: $a0=Matrix A, $a1=Vector b, $a2=Vector x, $a3=N
# ---------------------------------------------------------
solveLinearSystem:
    addi $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)  
    sw $s1, 12($sp) 
    sw $s2, 8($sp)  
    sw $s4, 4($sp)  
    sw $s5, 0($sp)  
    l.s $f26, EPSILON       # Nguong so sanh
    li $s0, 0               # i (pivot index)
Pivot_loop:
    bge $s0, $a3, Assignment_start  
    
    # 1. Tim phan tu Pivot lon nhat trong cot
    move $s4, $s0
    move $s2, $s0
    jal Get_matrix_addr
    l.s $f2, 0($t0)         # Lay gia tri hien tai
    abs.s $f2, $f2
    addi $s1, $s0, 1        # Duyet cac hang duoi
Search_pivot_loop:
    bge $s1, $a3, Pivot_check
    move $s5, $s0       
    move $s0, $s1
    jal Get_matrix_addr
    move $s0, $s5
    l.s $f4, 0($t0)
    abs.s $f4, $f4
    c.lt.s $f2, $f4         # So sanh de tim max
    bc1t Swap
    j End_search_pivot
Swap:
    move $s4, $s1           # Luu vi tri hang co pivot lon nhat
    mov.s $f2, $f4
End_search_pivot:
    addi $s1, $s1, 1
    j Search_pivot_loop
Pivot_check:
    c.lt.s $f2, $f26        # Kiem tra ma tran suy bien
    bc1t Singular_Error
    
    # 2. Hoan doi hang neu can
    beq $s4, $s0, Pivot_normalizationn
    move $s1, $s4
    li $s2, 0
Swap_col_c_loop:
    bge $s2, $a3, Swap_b
    jal Get_matrix_addr     
    move $t7, $t0
    l.s $f0, 0($t7)
    move $s5, $s0           
    move $s0, $s1
    jal Get_matrix_addr
    move $t6, $t0
    l.s $f1, 0($t6)         
    move $s0, $s5
    s.s $f1, 0($t7)         # Swap A[i][c] va A[pivot][c]
    s.s $f0, 0($t6)
    addi $s2, $s2, 1
    j Swap_col_c_loop
Swap_b:                     # Swap vector b
    sll $t0, $s0, 2
    add $t0, $a1, $t0
    l.s $f0, 0($t0)
    sll $t1, $s1, 2
    add $t1, $a1, $t1
    l.s $f1, 0($t1)
    s.s $f1, 0($t0)
    s.s $f0, 0($t1)

    # 3. Chuan hoa hang Pivot (Chia hang cho Pivot de phan tu cheo = 1)
Pivot_normalizationn:
    move $s2, $s0
    jal Get_matrix_addr     
    l.s $f6, 0($t0)         # Gia tri pivot
    l.s $f5, one_f
    div.s $f7, $f5, $f6     # He so 1/pivot
    li $s2, 0
Normalize_c_loop:
    bge $s2, $a3, Normalize_b
    jal Get_matrix_addr
    l.s $f10, 0($t0)        
    mul.s $f10, $f10, $f7   # A[i][c] = A[i][c] / pivot
    s.s $f10, 0($t0)
    addi $s2, $s2, 1
    j Normalize_c_loop
Normalize_b:
    sll $t0, $s0, 2 
    add $t0, $a1, $t0
    l.s  $f14, 0($t0)
    mul.s $f14, $f14, $f7   # b[i] = b[i] / pivot
    s.s $f14, 0($t0)

    # 4. Khu cac hang khac (Elimination)
    li $s1, 0
Elimination_r_loop:
    bge $s1, $a3, End_elimination_r
    beq $s1, $s0, Continue_r
    move $s2, $s0
    move $s5, $s0
    move $s0, $s1
    jal Get_matrix_addr
    l.s $f8, 0($t0)         # He so khu
    move $s0, $s5
    li $s2, 0
Elimination_c_loop:         # Tru cac cot
    bge $s2, $a3, Elimination_b
    move $s5, $s0
    move $s0, $s1
    jal Get_matrix_addr
    move $t3, $t0
    l.s $f12, 0($t0)
    move $s0, $s5
    jal Get_matrix_addr
    l.s $f10, 0($t0)
    mul.s $f18, $f8, $f10
    sub.s $f12, $f12, $f18  # A[r][c] -= factor * A[i][c]
    s.s $f12, 0($t3)
    addi $s2, $s2, 1
    j Elimination_c_loop
Elimination_b:              # Tru vector b
    sll $t0, $s1, 2
    add $t0, $a1, $t0
    l.s $f16, 0($t0)
    sll $t1, $s0, 2
    add $t1, $a1, $t1
    l.s $f14, 0($t1)
    mul.s $f18, $f8, $f14
    sub.s $f16, $f16, $f18  # b[r] -= factor * b[i]
    s.s $f16, 0($t0)
Continue_r:
    addi $s1, $s1, 1
    j Elimination_r_loop
End_elimination_r:
    addi $s0, $s0, 1
    j Pivot_loop

    # 5. Gan ket qua
Assignment_start:
    li $s0, 0
Assignment_loop:
    bge $s0, $a3, END_SOLVE
    sll $t0, $s0, 2
    add $t1, $a1, $t0
    add $t2, $a2, $t0
    l.s $f0, 0($t1)
    s.s $f0, 0($t2)         # x[i] = b[i]
    addi $s0, $s0, 1
    j Assignment_loop

Singular_Error:
    li $v0, 4
    la $a0, singular
    syscall
    li $s0, 0
    l.s $f0, zero_f
Singular_Loop:
    bge $s0, $a3, END_SOLVE
    sll $t0, $s0, 2
    add $t1, $a2, $t0
    s.s $f0, 0($t1)
    addi $s0, $s0, 1
    j Singular_Loop

END_SOLVE:
    lw   $ra, 20($sp)
    lw   $s0, 16($sp)
    lw   $s1, 12($sp)
    lw   $s2, 8($sp)
    lw   $s4, 4($sp)
    lw   $s5, 0($sp)
    addi $sp, $sp, 24
    jr $ra

Get_matrix_addr:
    mul $t0, $s0, $a3
    add $t0, $t0, $s2
    sll $t0, $t0, 2
    add $t0, $a0, $t0
    jr $ra

# ---------------------------------------------------------
# Ham: applyWienerFilter
# Cong thuc: y[n] = sum(h[k] * x[n-k])
# Input: $a0=input, $a1=coeff(h), $a2=output, $a3=N
# ---------------------------------------------------------
applyWienerFilter:
    addi $sp, $sp, -16
    sw   $ra, 12($sp)
    sw   $s0, 8($sp)
    sw   $s1, 4($sp)
    
    li $s0, 0               # n = 0
Outer_loop_n_filter:
    bge $s0, $a3, End_n_loop_filter
    l.s $f2, zero_f         # sum = 0
    li $s1, 0               # k = 0
Inner_loop_k_filter:
    bge $s1, $a3, End_k_loop_filter
    sub $t0, $s0, $s1       # index = n - k
    bltz $t0, Skip_term_filter # Neu n-k < 0 thi bo qua
    
    # Load h[k]
    sll $t1, $s1, 2
    add $t2, $a1, $t1       
    l.s $f4, 0($t2)
    
    # Load x[n-k]
    sll $t1, $t0, 2
    add $t2, $a0, $t1
    l.s $f6, 0($t2)
    
    mul.s $f8, $f4, $f6
    add.s $f2, $f2, $f8     # sum += h[k]*x[n-k]
Skip_term_filter:
    addi $s1, $s1, 1
    j Inner_loop_k_filter
End_k_loop_filter:
    sll $t1, $s0, 2
    add $t2, $a2, $t1
    s.s $f2, 0($t2)         # Luu vao output[n]
    addi $s0, $s0, 1
    j Outer_loop_n_filter
End_n_loop_filter:
    lw   $ra, 12($sp)
    lw   $s0, 8($sp)
    lw   $s1, 4($sp)
    addi $sp, $sp, 16
    jr $ra

print_all_content:
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)
    
    li $v0, 4
    la $a0, header_filtered
    syscall
    
    la $s1, output_signal
    lw $s2, NUM_SAMPLES
    li $s3, 0
term_loop:
    bge $s3, $s2, term_mmse
    l.s $f12, 0($s1)
    la $a0, str_buf
    li $a1, 1
    jal float_to_str
    li $v0, 4
    la $a0, str_buf
    syscall

    addi $t0, $s2, -1
    beq $s3, $t0, Skip_space

    li $v0, 4
    la $a0, space_str
    syscall
Skip_space:
    addi $s3, $s3, 1
    addi $s1, $s1, 4
    j term_loop
term_mmse:
    li $v0, 4
    la $a0, header_mmse
    syscall
    la $t0, mmse
    l.s $f12, 0($t0)
    la $a0, str_buf
    li $a1, 1
    jal float_to_str
    li $v0, 4
    la $a0, str_buf
    syscall
    lw $ra, 0($sp)
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $s3, 12($sp)
    addi $sp, $sp, 16
    jr $ra

# ---------------------------------------------------------
# Ham lam tron so float
# ---------------------------------------------------------
round_to_1dec:
    l.s $f1, ten        
    l.s $f2, half       
    l.s $f4, minus_half 
    l.s $f5, zero_f     

    mul.s $f3, $f12, $f1
    c.lt.s $f3, $f5
    bc1f pos_round
    add.s $f3, $f3, $f4
    j do_convert
pos_round:
    add.s $f3, $f3, $f2
do_convert:
    cvt.w.s $f6, $f3
    cvt.s.w $f0, $f6
    div.s $f0, $f0, $f1
    jr $ra

# ---------------------------------------------------------
# Ham chuyen float sang chuoi (FIX -0.0)
# ---------------------------------------------------------
float_to_str:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    move $t9, $a0
    
    # Nap lai hang so
    l.s $f10, zero_f
    li $t5, 0                # Co dau (0=duong, 1=am)

    # 1. Kiem tra so am
    c.lt.s $f12, $f10
    bc1f handle_pos_fs
    
    li $t5, 1                # Danh dau am
    neg.s $f12, $f12         

handle_pos_fs:
    # 2. Lam tron
    jal round_to_1dec        
    mov.s $f12, $f0          

    # --- [FIX QUAN TRONG] Kiem tra -0.0 ---
    l.s $f10, zero_f         
    c.eq.s $f12, $f10        # Neu ket qua lam tron == 0.0
    bc1t skip_sign_print     # Bo qua in dau tru

    # Neu khac 0.0, in dau tru neu can
    beqz $t5, skip_sign_print
    li $t0, '-'
    sb $t0, 0($t9)
    addi $t9, $t9, 1

skip_sign_print:
    l.s $f1, ten             
    
    mul.s $f12, $f12, $f1
    cvt.w.s $f12, $f12
    mfc1 $t1, $f12
    li $t2, 10
    div $t1, $t2
    mflo $t3
    mfhi $t4
    
    addi $sp, $sp, -4
    sw $t4, 0($sp)
    
    move $a1, $t9
    move $a2, $t3
    jal itoa_helper
    move $t9, $a1
    
    lw $t4, 0($sp)
    addi $sp, $sp, 4
    
    li $t0, '.'
    sb $t0, 0($t9)
    addi $t9, $t9, 1
    addi $t4, $t4, '0'
    sb $t4, 0($t9)
    addi $t9, $t9, 1
    sb $zero, 0($t9)
    sub $v0, $t9, $a0        
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

itoa_helper:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    move $t0, $a1
    move $t1, $a2
    li $t2, 0
    beq $t1, $zero, itoa_zero
itoa_loop:
    beq $t1, $zero, itoa_rev_prep
    li $t3, 10
    div $t1, $t3
    mflo $t1
    mfhi $t4
    addi $t4, $t4, '0'
    sb $t4, 0($t0)
    addi $t0, $t0, 1
    addi $t2, $t2, 1
    j itoa_loop
itoa_zero:
    li $t4, '0'
    sb $t4, 0($t0)
    addi $t0, $t0, 1
    li $t2, 1
    j itoa_end
itoa_rev_prep:
    move $t3, $a1
    addi $t4, $t0, -1
rev_loop:
    bge $t3, $t4, itoa_end
    lb $t5, 0($t3)
    lb $t6, 0($t4)
    sb $t6, 0($t3)
    sb $t5, 0($t4)
    addi $t3, $t3, 1
    addi $t4, $t4, -1
    j rev_loop
itoa_end:
    move $v0, $t2
    move $a1, $t0
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra