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
  li $a1, 15	# x coordinate
  li $a2, 100	# y coordinate
  lw $t0, iheight($a0)
  sub $a2, $t0, $a2
  li $s0, 195		#$s0 = size of the pattern
  move $s1, $s0
  sll $s1, $s1, 1
  subiu $s1, $s1, 1	#$s1 = the length of the pattern
  move $s2, $s1		#$s2 = number of lines to be drawn
  li $a3, 1	# color
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
	beq $s1, 1, middle_line
	move $t2, $s1			#s3 - middle lane draw flag
	
	li $t1, 0xff			#first couple of bits in one of the middle lines
	li $t3, 8
	rem $t4, $a1, 8
	sub $t3, $t3, $t4
	bleu $s1, $t3, short_pattern
	sllv $t1, $t1, $t3
	srl $t1, $t1, 1
	sub $t2, $t2, $t3
chroma_pattern:
	beq $a3, 1, chroma_pattern_white			#color checks
	beq $a3, 3, chroma_pattern_invert
	lb $t4, ($t0)
	not $t4, $t4
	not $t1, $t1
	or $t1, $t1, $t4
	not $t1, $t1
	sb $t1, ($t0)
	j chroma_pattern_check
chroma_pattern_white:
	lb $t4, ($t0)
	not $t1, $t1
	or $t1, $t1, $t4
	sb $t1, ($t0)
	j chroma_pattern_check
chroma_pattern_invert:
	lb $t4, ($t0)			
	xor $t1, $t1, $t4		#changing a color depending on the background
	not $t1, $t1
	sb $t1, ($t0)
chroma_pattern_check:
	bgtu $t2, 8, fill_pattern
	bnez $t2, end_pattern
	j end_line 
short_pattern:
	li $t1, 0x01
	subiu $t3, $t3, 2
	subiu $t2, $t2, 2
	sllv $t1, $t1, $t3
	move $t4, $t1
	subiu $t2, $t2, 1
short_pattern_loop:
	beqz $t2, chroma_pattern_pre
	srl $t4, $t4, 1
	or $t1, $t1, $t4
	subiu $t2, $t2, 1
	j short_pattern_loop
chroma_pattern_pre:
	not $t1, $t1
	j chroma_pattern
fill_pattern:
	addiu $t0, $t0, 1
	addiu $t9, $t9, 1
	li $t1, 0x00
	subiu $t2, $t2, 8
	j chroma_pattern
end_pattern:
	addiu $t0, $t0, 1
	addiu $t9, $t9, 1
	li $t1, 0xff
	subiu $t2, $t2, 1
	srlv $t1, $t1, $t2
	move $t2, $zero
	j chroma_pattern
#########################################################	
end_line:			#next line check
	sub $t0, $t0, $t9
	move $t9, $0
	lw $t3, iwidth($a0)
	div $t3, $t3, 8
	subiu $a2, $a2, 1
	beqz $a2, fin
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
	move $s5, $s1
	move $t3, $t5
	mul $t3, $t3, 2
	sub $s5, $s5, $t3		#s5 - length of the gap
	move $t7, $s5

odd_init:
	move $s6, $s5
	div $s6, $s6, 2
	addiu $s6, $s6, 1
	move $s7, $zero
		
	li $t1, 0x01
	li $t3, 8
	div $t3, $a1, $t3
	addiu $t3, $t3, 1
	mul $t3, $t3, 8
	sub $t3, $t3, $a1
	subiu $t3, $t3, 1
	sllv $t1, $t1, $t3
	move $t4, $t1
dots_odd:
	beq $t3, 0, chroma_odd			#always ends with 1
	beq $t3, 1, chroma_odd			#always ends with 0
	beqz $t6, gap_start	
	srl $t4, $t4, 2
	or $t1, $t1, $t4
	subiu $t3, $t3, 2
	subiu $t6, $t6, 1	
	j dots_odd
chroma_odd:
	move $t8, $t1
	sll $t8, $t8, 30
	srl $t8, $t8, 24
	
	beq $a3, 1, chroma_odd_white
	beq $a3, 3, chroma_odd_invert
	not $t1, $t1
	lb $t4, ($t0)
	not $t4, $t4
	not $t1, $t1
	or $t1, $t1, $t4
	not $t1, $t1
	sb $t1, ($t0)
	j chroma_odd_check
chroma_odd_white:
	not $t1, $t1
	lb $t4, ($t0)
	not $t1, $t1
	or $t1, $t1, $t4
	sb $t1, ($t0)
	j chroma_odd_check
chroma_odd_invert:				
	not $t1, $t1
	lb $t4, ($t0)
	xor $t1, $t1, $t4		#changing a color depending on the background
	not $t1, $t1
	sb $t1, ($t0)
chroma_odd_check:
	bnez $t6, prep_dots_odd
	bgeu $t7, 8, gap_fill
	bnez $t7, gap_end
	j end_line
prep_dots_odd:
	addiu $t9, $t9, 1
	addiu $t0, $t0, 1
	addiu $t3, $t3, 6
	move $t1, $t8
	move $t4, $t1
	subiu $t6, $t6, 1
	j dots_odd
dots_start_odd:
	beq $a3, 1, chroma_odd_white_emer			#emergency chroma operation is required
	beq $a3, 3, chroma_odd_invert_emer
	not $t1, $t1
	lb $t4, ($t0)
	not $t4, $t4
	not $t1, $t1
	or $t1, $t1, $t4
	not $t1, $t1
	sb $t1, ($t0)
	j chroma_odd_post
chroma_odd_white_emer:
	not $t1, $t1
	lb $t4, ($t0)
	not $t1, $t1
	or $t1, $t1, $t4
	sb $t1, ($t0)
	j chroma_odd_post
chroma_odd_invert_emer:				
	not $t1, $t1
	lb $t4, ($t0)
	xor $t1, $t1, $t4		#changing a color depending on the background
	not $t1, $t1
	sb $t1, ($t0)
chroma_odd_post:	
	addiu $t9, $t9, 1
	addiu $t0, $t0, 1
	li $t1, 0x80
	move $t4, $t1
	move $t6, $s4
	li $t3, 7
	j dots_odd
gap_start:
	beqz $t7, chroma_odd
	bgtu $t3, $t7, no_gap
	sub $t7, $t7, $t3
	move $t3, $zero
	bgtu $s6, $t7, middle_dot 
	beqz $t7, dots_start_odd
	j chroma_odd
gap_fill:
	sub $t7, $t7, $t3
	move $t3, $zero
	li $t1, 0x00
	addiu $t9, $t9, 1
	addiu $t0, $t0, 1	
	subiu $t7, $t7, 8
	bgtu $s6, $t7, middle_dot 	
	beqz $t7, dots_start_odd
	j chroma_odd
middle_dot:
	sub $t3, $s6, $t7
	subiu $t3, $t3, 1
	li $t4, 0x01
	sllv $t4, $t4, $t3
	or $t1, $t1, $t4
	move $s6, $zero
	move $t3, $zero
	beqz $t7, dots_start_odd
	j chroma_odd
gap_end:
	sub $t7, $t7, $t3
	addiu $t9, $t9, 1
	addiu $t0, $t0, 1
	li $t1, 0x80
	srlv $t1, $t1, $t7
	move $t4, $t1	
	li $t3, 7
	sub $t3, $t3, $t7
	move $t7, $zero
	move $t6, $s4
	bnez $s6, middle_dot_at_the_end
	j dots_odd
middle_dot_at_the_end:				#special case where the middle dot has to be placed in the byte with the end of the gap
	sllv $t4, $t4, $s6
	or $t1, $t1, $t4
	srlv $t4, $t4, $s6
	move $s6, $zero
	j dots_odd
no_gap:						#special case where the gap is so short that it fits in a single 8 bits
	addiu $t7, $t7, 1
	sub $t3, $t3, $t7
	srlv $t4, $t4, $t7
	move $t7, $zero
	or $t1, $t1, $t4
	move $t6, $s4
	bnez $s6, middle_dot_at_the_end
	j dots_odd 
#########################################################
even_row:
	subiu $t3, $s0, 2
	beq $t3, $t5, even_is_odd
	move $s4, $t5
	subiu $s4, $s4, 2
	div $s4, $s4, 2			#s4 - number of dost per side
	move $s5, $s1
	move $t3, $t5
	mul $t3, $t3, 2
	sub $s5, $s5, $t3		
	sub $s5, $s5, 2			#s5 - length of the solid line
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
	beqz $t6, line_start
	srl $t4, $t4, 2
	or $t1, $t1, $t4
	subiu $t3, $t3, 2
	subiu $t6, $t6, 1	
	j dots_even
chroma_even:
	move $t8, $t1
	sll $t8, $t8, 30
	srl $t8, $t8, 24
	
	beq $a3, 1, chroma_even_white
	beq $a3, 3, chroma_even_invert
	not $t1, $t1
	lb $t4, ($t0)
	not $t4, $t4
	not $t1, $t1
	or $t1, $t1, $t4
	not $t1, $t1
	sb $t1, ($t0)
	j chroma_even_check
chroma_even_white:
	not $t1, $t1
	lb $t4, ($t0)
	not $t1, $t1
	or $t1, $t1, $t4
	sb $t1, ($t0)
	j chroma_even_check
chroma_even_invert:				
	not $t1, $t1
	lb $t4, ($t0)
	xor $t1, $t1, $t4		#changing a color depending on the background
	not $t1, $t1
	sb $t1, ($t0)
chroma_even_check:
	bnez $t6, prep_dots_even
	bgtu $t7, 8, line_fill
	bnez $t7, line_end
	j end_line
prep_dots_even:
	addiu $t9, $t9, 1
	addiu $t0, $t0, 1
	addiu $t3, $t3, 6
	move $t1, $t8
	move $t4, $t1
	subiu $t6, $t6, 1
	j dots_even
line_start:
	sub $t2, $t3, 2
	bleu $t7, $t2, chroma_even
	bltu $t3, 3, chroma_even
	li $t4, 0xff
	sub $t3, $t3, 2
	li $t2, 8
	sub $t2, $t2, $t3
	srlv $t4, $t4, $t2
	or $t1, $t1, $t4
	sub $t7, $t7, $t3
	j chroma_even	
line_fill:
	addiu $t9, $t9, 1
	addiu $t0, $t0, 1
	beq $t7, $s5, special_fill_0		#when the fill is also a begining of a line
	li $t1, 0xff
	subiu $t7, $t7, 8
	j chroma_even
special_fill_0:	
	beq $t3, 1, special_fill_1
	beq $t3, 2, special_fill_2
	li $t1, 0x3f
	subiu $t7, $t7, 6
	j chroma_even
special_fill_1:
	li $t1, 0x7f
	subiu $t7, $t7, 7
	j chroma_even
special_fill_2:
	li $t1, 0xff
	subiu $t7, $t7, 8
	j chroma_even
line_end:
	addiu $t9, $t9, 1
	addiu $t0, $t0, 1
	beq $t7, $s5, only_one_line
	li $t3, 8
	sub $t3, $t3, $t7
	li $t7, 0
	li $t1, 0xff
	sllv $t1, $t1, $t3
	addiu $t6 $s4, 1
	bltu $t3, 3, special_line_end_0				#when the space after the end of filling the end of the line does not allow to place the first dot in the sequence
	subiu $t3, $t3, 3
	li $t4, 0x01
	sllv $t4, $t4, $t3
	or $t1, $t1, $t4
	subiu $t6, $t6, 1
	j dots_even
special_line_end_0:

	beq $a3, 1, chroma_even_white_emer1			#emergency chroma operation is required, because the prev line has to be saved without the checks present in regular chroma
	beq $a3, 3, chroma_even_invert_emer1
	not $t1, $t1
	lb $t4, ($t0)
	not $t4, $t4
	not $t1, $t1
	or $t1, $t1, $t4
	not $t1, $t1
	sb $t1, ($t0)
	j chroma_even_post1
chroma_even_white_emer1:
	not $t1, $t1
	lb $t4, ($t0)
	not $t1, $t1
	or $t1, $t1, $t4
	sb $t1, ($t0)
	j chroma_even_post1
chroma_even_invert_emer1:				
	not $t1, $t1
	lb $t4, ($t0)
	xor $t1, $t1, $t4		#changing a color depending on the background
	not $t1, $t1
	sb $t1, ($t0)
	
chroma_even_post1:	
	addiu $t9, $t9, 1
	addiu $t0, $t0, 1
	beq $t3, 1, special_line_end_1
	beq $t3, 2, special_line_end_2	
	li $t1, 0x20
	move $t4, $t1
	subiu $t6, $t6, 1
	li $t3, 5
	j dots_even
special_line_end_1:
	li $t1, 0x40
	move $t4, $t1
	subiu $t6, $t6, 1
	li $t3, 6
	j dots_even
special_line_end_2:
	li $t1, 0x80
	move $t4, $t1
	subiu $t6, $t6, 1
	li $t3, 7
	j dots_even
only_one_line:
	beq $t3, 0, only_one_line_0		#if line is so short, that it fits in a single 8bit byte
	beq $t3, 1, only_one_line_1
	beq $t3, 2, only_one_line_2
	
	subiu $t9, $t9, 1
	subiu $t0, $t0, 1
	li $t4, 0xff		#reverse prev save
	sb $t4, ($t0)
	not $t1, $t1
	
	li $t4, 0x01
	subiu $t3, $t3, 3
	sllv $t4, $t4, $t3
	or $t1, $t1, $t4
	subiu $t7, $t7, 1
	srl $t4, $t4, 1
	j only_one_line_loop
only_one_line_0:
	beq $t7, 7, special_case_one_line
	li $t1, 0x20
	subiu $t7, $t7, 1
	li $t3, 5
	srl $t4, $t1, 1
	j only_one_line_loop
only_one_line_1:
	li $t1, 0x40
	subiu $t7, $t7, 1
	li $t3, 6
	srl $t4, $t1, 1
	j only_one_line_loop
only_one_line_2:
	li $t1, 0x80
	subiu $t7, $t7, 1
	li $t3, 7
	srl $t4, $t1, 1
only_one_line_loop:
	or $t1, $t1, $t4
	subiu $t7, $t7, 1
	subiu $t3, $t3, 1
	srl $t4, $t4, 1
	bnez $t7, only_one_line_loop
	addiu $t6, $s4, 1
	bltu $t3, 3, special_line_end_0
	subiu $t3, $t3, 3
	li $t4, 0x01
	sllv $t4, $t4, $t3
	or $t1, $t1, $t4
	subiu $t6, $t6, 1
	j dots_even
special_case_one_line:						#very special case where the line is length 8, and the byte that will be written starts with one clear space, so there is a need to go to the next line to place first dot in the sequence 
	li $t1, 0x3f
	
	beq $a3, 1, chroma_even_white_emer2			#emergency chroma operation is required
	beq $a3, 3, chroma_even_invert_emer2
	not $t1, $t1
	lb $t4, ($t0)
	not $t4, $t4
	not $t1, $t1
	or $t1, $t1, $t4
	not $t1, $t1
	sb $t1, ($t0)
	j chroma_even_post2
chroma_even_white_emer2:
	not $t1, $t1
	lb $t4, ($t0)
	not $t1, $t1
	or $t1, $t1, $t4
	sb $t1, ($t0)
	j chroma_even_post2
chroma_even_invert_emer2:				
	not $t1, $t1
	lb $t4, ($t0)
	xor $t1, $t1, $t4		#changing a color depending on the background
	not $t1, $t1
	sb $t1, ($t0)
	
chroma_even_post2:	
	addiu $t0, $t0, 1
	addiu $t9, $t9, 1
	li $t1, 0x90
	li $t4, 0x10
	move $t7, $zero
	li $t3, 5
	move $t6, $s4
	j dots_even
#########################################################
even_is_odd:
	subiu $t3, $t5, 1
	move $s4, $t3
	div $s4, $s4, 2			#s4 - number of dost per side
	move $t6, $s4
	
	move $s5, $s1
	move $t2, $t3
	mul $t2, $t2, 2
	sub $s5, $s5, $t2
	move $t7, $s5
	j odd_init
#########################################################
middle_line:
	move $t2, $s1
	li $s3, 1			#s3 - middle lane draw flag
	
	li $t1, 0xff			#first couple of bits in one of the middle lines
	li $t3, 8
	rem $t4, $a1, 8
	sub $t3, $t3, $t4
	bltu $s1, $t3, short_middle
	sllv $t1, $t1, $t3
	sub $t2, $t2, $t3
chroma_middle:
	beq $a3, 1, chroma_middle_white
	beq $a3, 3, chroma_middle_invert
	lb $t4, ($t0)
	not $t4, $t4
	not $t1, $t1
	or $t1, $t1, $t4
	not $t1, $t1
	sb $t1, ($t0)
	j chroma_middle_check
chroma_middle_white:
	lb $t4, ($t0)
	not $t1, $t1
	or $t1, $t1, $t4
	sb $t1, ($t0)
	j chroma_middle_check
chroma_middle_invert:
	lb $t4, ($t0)			
	xor $t1, $t1, $t4		#changing a color depending on the background
	not $t1, $t1
	sb $t1, ($t0)
chroma_middle_check:
	bgeu $t2, 8, fill_middle
	bnez $t2, end_middle
	j end_line 
short_middle:
	li $t1, 0x01
	subiu $t3, $t3, 1
	sllv $t1, $t1, $t3
	move $t4, $t1
	subiu $t2, $t2, 1
short_middle_loop:
	beqz $t2, chroma_middle_pre
	srl $t4, $t4, 1
	or $t1, $t1, $t4
	subiu $t2, $t2, 1
	j short_middle_loop
chroma_middle_pre:
	not $t1, $t1
	j chroma_middle
fill_middle:
	addiu $t0, $t0, 1
	addiu $t9, $t9, 1
	li $t1, 0x00
	subiu $t2, $t2, 8
	j chroma_middle
end_middle:
	addiu $t0, $t0, 1
	addiu $t9, $t9, 1
	li $t1, 0xff
	srlv $t1, $t1, $t2
	move $t2, $zero
	j chroma_middle
#########################################################
fin:
	jr $ra
