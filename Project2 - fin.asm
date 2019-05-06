  .data
fname: 	.asciiz "checkboard.bmp"
oname:	.asciiz "output.bmp"

imgInfo:
_isize:		.word 0     # offset 0 to pInfo
_iwidth:	.word 0		# offset 4 
_iheight:	.word 0		# offset 8 
_ilinesize:	.word 0		# offset 12
_pImg:		.word 0		# offset 16

	.eqv isize 0
	.eqv iwidth 4
	.eqv iheight 8
	.eqv ilinesize 12
	.eqv pImg 16


bmpbuf:	.space 32000

  .text
main:
# be vigilant here I assume that $a3 contains pointer
# to the image descriptor
  la $a3, imgInfo

  la $a0, fname
  li $a1, 0
  li $a2, 0
  li $v0, 13	# open file (read-only)
  syscall

  move $a0, $v0
  la $a1, bmpbuf	# no other way in main 
  li $a2, 32000
  li $v0, 14	# read file
  syscall
  
  sw $v0, isize($a3) # file size in bytes
  
  li $v0, 16	# close file
  syscall

  # $a1 contains the address of bitmap buffer (header first, pixels next)
  lhu $t0, 18($a1) # width at offset 18
  sw $t0, iwidth($a3)
  
  lhu $t0, 22($a1) # height at offset 22
  sw $t0, iheight($a3)
  
  add $t0, $a1, 62
  sw $t0, pImg($a3)

  # there is new ilinesize (in bytes) field to compute
  lw $t0, iwidth($a3)
  add $t0, $t0, 31
  sra $t0, $t0, 5
  sll $t0, $t0, 2
  sw $t0, ilinesize($a3)
  
  
  # pixel data starts at offset 62
  #sb $zero, 62($a1)
  
  la $a0, imgInfo
  li $a1, 3	# x coordinate
  li $a2, 20	# y coordinate
  lw $t0, iheight($a0)
  sub $a2, $t0, $a2
  li $s0, 77	#size of the pattern
  move $s1, $s0
  sll $s1, $s1, 1
  subiu $s1, $s1, 1	#$s1 = the length of the pattern
  move $s2, $s1		#$s2 = number of lines to be drawn
  li $a3, 0	# color
  jal putpixel
  
  la $a0, oname
  li $a1, 1
  li $a2, 0
  li $v0, 13	# open file (write-only)
  syscall
  
    la $a3, imgInfo  # again pInfo in $a3

  move $a0, $v0
  la $a1, bmpbuf
  lw $a2, isize($a3)
  li $v0, 15	# write file
  syscall

  li $v0, 16	# close file
  syscall
    
  li $v0, 10
  syscall

# int imgRead(imgInfo *pInfo, const char* fname);
#                       $a0                $a1
# int imgWrite(imgInfo *pInfo, const char* fname);
#                        $a0                $a1

# void putpixel(imgInfo *pInfo, int x, int y, int color);
#		$a0		   $a1	  $a2      $a3
putpixel:
	lw $t0, ilinesize($a0) # width of the line in bytes
	mul $t0, $t0, $a2	   # offset of line
	
	sra $t1, $a1, 3        # offset of pixel in line: x / 8
	add $t0, $t0, $t1	   # offset of pixel's byte in image
	
	lw $t1, pImg($a0)
	add $t0, $t0, $t1	   # address of byte containing pixel

	
	# pixel mask: 0x80 >> (x % 8)
	# pixel offset in byte
	and $t1, $a1, 0x7
	li $t2, 0x80
	srlv $t1, $t2, $t1
	
	lb $t2, ($t0)
	beq $a3, $zero, clear_pixel
	
	or $t2, $t2, $t1
	#sb $t2, ($t0)
	j pattern
clear_pixel:
	not $t1, $t1
	and $t2, $t2, $t1
	#sb $t2, ($t0)
	j pattern
#########################################################
pattern:
	li $t1, 0xff
	move $t2, $s1
	li $t3, 8
	div $t3, $a1, $t3
	addiu $t3, $t3, 1
	mul $t3, $t3, 8
	sub $t3, $t3, $a1
	sub $t2, $t2, $t3
	subiu $t3, $t3, 1
	sllv $t1, $t1, $t3
	lb $t4, ($t0)		#changing a color depending on the background
	xor $t1, $t1, $t4
	not $t1, $t1
	sb $t1, ($t0)
copy:
	li $t3, 8		#bits in the middle of the line
	div $t3, $t2, $t3
	beqz $t3, last_bit
	bge $t3, 2, more_than_one
	mulu $t3, $t3, 8
	sub $t3, $t3, $t2
	beqz $t3, last_bit
more_than_one:			#sanity checks for the remaining bits
	addiu $t0, $t0, 1	
	addiu $t9, $t9, 1
	li $t1, 0x00
	lb $t4, ($t0)		#changing a color depending on the background
	xor $t1, $t1, $t4
	not $t1, $t1
	sb $t1, ($t0) 
	subiu $t2, $t2, 8
	j copy
last_bit:
	addiu $t0, $t0, 1	#last couple of bits in a straight line
	addiu $t9, $t9, 1
	li $t1, 0xff
	subiu $t2, $t2, 1
	srlv $t1, $t1, $t2
	lb $t4, ($t0)		#changing a color depending on the background
	xor $t1, $t1, $t4
	not $t1, $t1
	sb $t1, ($t0)
#########################################################	
end_line:			#next line check
	sub $t0, $t0, $t9
	move $t9, $0
	lw $t3, iwidth($a0)
	div $t3, $t3, 8
	sub $t0, $t0, $t3
	subiu $s2, $s2, 1
	beq $s2, 1, pattern
	beqz $s2, fin	
#########################################################
flag_yes:
	bne $s3, 1, flag_no
	subiu $t5, $t5, 1
	j row_number_check
flag_no:
	addiu $t5, $t5, 1
row_number_check:
	move $t3, $s0
	subiu $t3, $t3, 1
	beq $t5, $t3, middle_line
	rem $t3, $t5, 2
	beq $t3, 1, odd_row
	j even_row
#########################################################
odd_row:
	move $s4, $t5
	div $s4, $s4, 2			#s4 - number of dost per side
	move $t6, $s4
	
	li $t1, 0x01
	move $t2, $s1
	li $t3, 8
	div $t3, $a1, $t3
	addiu $t3, $t3, 1
	mul $t3, $t3, 8
	sub $t3, $t3, $a1
	sub $t2, $t2, $t3
	subiu $t3, $t3, 1
	sllv $t1, $t1, $t3
	j chroma
dots:
	beqz $t6, chroma
	move $t4, $t1
	srl $t4, $t4, 2
	or $t1, $t1, $t4
	subiu $t6, $t6, 1
	bnez $t6, dots
chroma:	
	not $t1, $t1
	lb $t4, ($t0)
	xor $t1, $t1, $t4		#changing a color depending on the background
	not $t1, $t1
	sb $t1, ($t0) 
copy_odd:					#middle couple of bits in one of the middle lines
	li $t3, 8
	div $t3, $t2, $t3
	beqz $t3, end_odd
	bge $t3, 2, more_than_one_odd
	mulu $t3, $t3, 8
	sub $t3, $t3, $t2
	beqz $t3, end_odd
more_than_one_odd:			#sanity checks for the remaining bits
	addiu $t0, $t0, 1
	addiu $t9, $t9, 1
	subiu $t2, $t2, 8
	j copy_odd
end_odd:
	addiu $t0, $t0, 1
	addiu $t9, $t9, 1
	li $t1, 0x01
	li $t3, 8
	sub $t3, $t3, $t2
	sllv $t1, $t1, $t3
	not $t1, $t1
	lb $t4, ($t0)
	xor $t1, $t1, $t4		#changing a color depending on the background
	not $t1, $t1
	sb $t1, ($t0)
	j end_line
#########################################################
even_row:
	move $s4, $t5
	subiu $s4, $s4, 2
	div $s4, $s4, 2			#s4 - number of dost per side
	move $s5, $s1
	move $t3, $t5
	mul $t3, $t3, 2
	sub $s5, $s5, $t3		#s5 - length of the solid line
	move $t6, $s4
	move $t7, $s5
	
	li $t1, 0x01
	li $t3, 8
	div $t3, $a1, $t3
	addiu $t3, $t3, 1
	mul $t3, $t3, 8
	sub $t3, $t3, $a1
	subiu $t3, $t3, 1
	sllv $t1, $t1, $t3
	move $t4, $t1
dots_even:
	beq $t3, 0, chroma_even			#always ends with 1
	beq $t3, 1, chroma_even			#always ends with 0
	beqz $t6, chroma_even
	srl $t4, $t4, 2
	or $t1, $t1, $t4
	subiu $t3, $t3, 2
	subiu $t6, $t6, 1	
	#beqz $t6, chroma_even
	j dots_even
chroma_even:
	move $t8, $t1
	sll $t8, $t8, 30
	srl $t8, $t8, 24
					
	not $t1, $t1
	lb $t4, ($t0)
	xor $t1, $t1, $t4		#changing a color depending on the background
	not $t1, $t1
	sb $t1, ($t0)
	bnez $t6, prep_dots_even
	j end_line
prep_dots_even:
	addiu $t9, $t9, 1
	addiu $t0, $t0, 1
	li $t3, 6
	move $t1, $t8
	move $t4, $t1
	subiu $t6, $t6, 1
	j dots_even
#########################################################
middle_line:
	li $s3, 1
	li $t1, 0xff			#first couple of bits in one of the middle lines
	li $t3, 8
	div $t3, $a1, $t3
	addiu $t3, $t3, 1
	mul $t3, $t3, 8
	sub $t3, $t3, $a1
	sllv $t1, $t1, $t3
	lb $t4, ($t0)
	xor $t1, $t1, $t4		#changing a color depending on the background
	not $t1, $t1
	sb $t1, ($t0) 
copy_m:					#middle couple of bits in one of the middle lines
	li $t3, 8
	div $t3, $t2, $t3
	beqz $t3, last_bit_m
	bge $t3, 2, more_than_one_m
	mulu $t3, $t3, 8
	sub $t3, $t3, $t2
	beqz $t3, last_bit_m
more_than_one_m:			#sanity checks for the remaining bits
	addiu $t0, $t0, 1
	addiu $t9, $t9, 1
	subiu $t2, $t2, 8
	bne $s2, $s0, copy_m
	li $t1, 0x00
	lb $t4, ($t0)		#changing a color depending on the background
	xor $t1, $t1, $t4
	not $t1, $t1
	sb $t1, ($t0) 
	j copy_m
last_bit_m:				#last couple of bits in one of the middle lines
	addiu $t0, $t0, 1
	addiu $t9, $t9, 1
	li $t1, 0xff
	srlv $t1, $t1, $t2
	lb $t4, ($t0)
	xor $t1, $t1, $t4		#changing a color depending on the background
	not $t1, $t1
	sb $t1, ($t0)
	j end_line
#########################################################
fin:
	jr $ra
	
	
	
	
