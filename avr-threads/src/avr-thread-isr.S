
/*
 * avr-thread-isr
 *
 * Preemptive task switcher.
 *
 * $Log$
 * Revision 1.1  2005-03-25 04:03:51  dean
 * Add files
 *
 * Revision 1.7  2004/03/13 02:53:23  dean
 * More conservative uart code with regards to cli()/sei().
 *
 * Revision 1.6  2004/02/28 19:15:45  dean
 * Fix sleep(0) bug in ISR code.
 *
 * Revision 1.5  2002/08/23 02:19:16  dean
 * Rename global names to avoid clashes.
 * Updated to work with new avr-gcc I/O.
 *
 * Revision 1.4  2001/04/05 07:55:07  dean
 * Uses rcall with smaller chips.
 *
 * Revision 1.3  2001/04/05 06:24:48  dean
 * Added DEBUG_STACK_USAGE.
 * avr_thread_isr_end() is now a called function to avoid losing
 * inlining of jmp when not optimizing.
 * Zeros out zero_reg before calling functions.
 * Disables interrupts when changing running and stack.
 *
 * Revision 1.2  2001/04/04 03:55:36  dean
 * Saves stack pointer to context in avr_thread_isr_start
 * instead of avr_thread_isr_end.
 *
 * Revision 1.1  2001/04/02 21:45:31  dean
 * Initial revision
 *
 */

#include <avr/io.h>
#include "avr-thread-asm.h"

	tmp_reg = 0
	zero_reg = 1

	.text

.global	avr_thread_isr_start
	.type	avr_thread_isr_start,@function
	
avr_thread_isr_start:
	/* Save registers where they belong (where possible). */
	/* Because return to isr is in the way, can't push Z. */
	PUSH_ALL_BUT_Z

	/* Save (SREG | BV(SREG_I))
         *
         * The reason for saving the SREG with global interrupts
         * enabled is that this thread was interrupted by an ISR,
	 * therefore, global interrupts were enabled at the time,
	 * regardless of what the ISR has done before reaching here.
         */
        
	in XL,_SFR_IO_ADDR(SREG)
        sbr XL,BV(SREG_I)
	push XL

        /* Save current stack pointer back to current context. */

#if ! DEBUG_STACK_USAGE
        ;; Try skipping test --- always save stack back to context.
	lds tmp_reg,avr_thread_disabled
	tst tmp_reg
	brne .no_switch_start

	lds YL,avr_thread_active
	lds YH,(avr_thread_active)+1
	in XL,_SFR_IO_ADDR(SPL)
	in XH,_SFR_IO_ADDR(SPH)
	
	std Y+CONTEXT_STACK_PTR,XL
	std Y+CONTEXT_STACK_PTR+1,XH
	
.no_switch_start:

#else
	lds YL,avr_thread_active
	lds YH,(avr_thread_active)+1
	in XL,_SFR_IO_ADDR(SPL)
	in XH,_SFR_IO_ADDR(SPH)

	lds tmp_reg,avr_thread_disabled
	tst tmp_reg
	brne .no_switch_start
	
	std Y+CONTEXT_STACK_PTR,XL
	std Y+CONTEXT_STACK_PTR+1,XH

.no_switch_start:

	/* Add the call from the isr plus the 4 extra pushes below. */
	sbiw XL,6
	ldd r24,Y+CONTEXT_MIN_STACK_PTR
	ldd r25,Y+CONTEXT_MIN_STACK_PTR+1
	cp XL,r24
	cpc XH,r25
	brsh .stack_greater_or_equal_stack_min
	std Y+CONTEXT_MIN_STACK_PTR,XL
	std Y+CONTEXT_MIN_STACK_PTR+1,XH

.stack_greater_or_equal_stack_min:
#endif

	/* Make room for copy of return address. */
	push XL
	push XL

	/* Save unsaved registers temporarily. */
	push ZH
	push ZL

	/* Setup temporary stack frame. */
	in YL,_SFR_IO_ADDR(SPL)
	in YH,_SFR_IO_ADDR(SPH)
	
	/* Copy return address so we can return with what's on the stack. */
	ldd XL,Y+4+CONTEXT_SIZE
	ldd XH,Y+4+CONTEXT_SIZE-1
	std Y+4,XL
	std Y+3,XH

	/* Copy Z register over old return address. */
	pop ZL
	std Y+4+CONTEXT_SIZE-1,ZL
	pop ZH
	std Y+4+CONTEXT_SIZE,ZH

	eor zero_reg,zero_reg
	ret

.global	avr_thread_isr_end
	.type	avr_thread_isr_end,@function
	
avr_thread_isr_end:

	/* Pop off unused return address. */
	pop tmp_reg
	pop tmp_reg
	
	lds XL,avr_thread_disabled
	tst XL
	brne .no_switch_end
	
	/* Find next thread to run.    */
	/* In isr. */
	/* Context address returned in r25:r24 */
	ldi r24,lo8(1)
	eor zero_reg,zero_reg
	in tmp_reg,_SFR_IO_ADDR(SREG)
        push tmp_reg
	cli
#if __AVR_ARCH__ == 3 || __AVR_ARCH__ == 5
	call avr_thread_find_next
#else
	rcall avr_thread_find_next
#endif
        pop tmp_reg
	out _SFR_IO_ADDR(SREG),tmp_reg
	mov YL,r24
	mov YH,r25
	sts avr_thread_active,YL
	sts (avr_thread_active)+1,YH

	/* Load new stack pointer. */
	ldd XL,Y+CONTEXT_STACK_PTR
	ldd XH,Y+CONTEXT_STACK_PTR+1
	in tmp_reg,_SFR_IO_ADDR(SREG)
	cli
	out _SFR_IO_ADDR(SPH),XH
	out _SFR_IO_ADDR(SPL),XL
	out _SFR_IO_ADDR(SREG),tmp_reg
	rjmp .isr_done

.no_switch_end:
	eor zero_reg,zero_reg
	in tmp_reg,_SFR_IO_ADDR(SREG)
        push tmp_reg
	cli
#if __AVR_ARCH__ == 3 || __AVR_ARCH__ == 5
	call avr_thread_tick_only
#else
	rcall avr_thread_tick_only
#endif
        pop tmp_reg
	out _SFR_IO_ADDR(SREG),tmp_reg

.isr_done:
	/* Restore SREG. */
	pop tmp_reg
        cbi tmp_reg,SREG_I
	out _SFR_IO_ADDR(SREG),tmp_reg
	
	/* Restore all registers. */
	POP_ALL

	reti
