
/*
 * avr-thread-switch
 *
 * Forced task switch.
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
 * Revision 1.5  2003/10/10 19:31:32  dean
 * dos2unix
 *
 * Revision 1.4  2002/08/23 02:19:19  dean
 * Rename global names to avoid clashes.
 * Updated to work with new avr-gcc I/O.
 *
 * Revision 1.3  2001/04/05 07:55:23  dean
 * Uses rcall with smaller chips.
 *
 * Revision 1.2  2001/04/05 06:26:39  dean
 * Added DEBUG_STACK_USAGE.
 * Disables interrupts when changing running and stack.
 *
 * Revision 1.1  2001/04/02 21:46:11  dean
 * Initial revision
 *
 */

#include <avr/io.h>
#include "avr-thread-asm.h"

	tmp_reg = 0
	zero_reg = 1

	.text


/* Enter this function with switcher disabled. */

.global	avr_thread_switch
	.type	avr_thread_switch,@function
	
avr_thread_switch:

	/* Save all registers. */
	PUSH_ALL

	/* Save SREG. */
	in XL,_SFR_IO_ADDR(SREG)
	sbr XL,BV(SREG_I)
	push XL

        /* Save current stack pointer back to current context. */
	lds YL,avr_thread_active
	lds YH,(avr_thread_active)+1
	in XL,_SFR_IO_ADDR(SPL)
	in XH,_SFR_IO_ADDR(SPH)

	std Y+CONTEXT_STACK_PTR,XL
	std Y+CONTEXT_STACK_PTR+1,XH

#if DEBUG_STACK_USAGE
	/* Add the pushes and call to avr_thread_find_next. */
	sbiw XL,6
	/* Disable interrupts because task switcher still updates */
	/* min_stack_ptr even while switcher is disabled. */
	in tmp_reg,_SFR_IO_ADDR(SREG)
	cli
	/* Add the call to avr_thread_find_next and its 4 pushes. */
	ldd r24,Y+CONTEXT_MIN_STACK_PTR
	ldd r25,Y+CONTEXT_MIN_STACK_PTR+1
	cp XL,r24
	cpc XH,r25
	brsh .stack_greater_or_equal_stack_min
	std Y+CONTEXT_MIN_STACK_PTR,XL
	std Y+CONTEXT_MIN_STACK_PTR+1,XH
.stack_greater_or_equal_stack_min:
	out _SFR_IO_ADDR(SREG),tmp_reg
#endif

	/* Find next thread to run.    */
	/* Not in isr. */
	/* Context address returned in r25:r24 */
	eor r24,r24
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
	/* Disable interrupts because task switcher still traverses */
	/* task list to update timeouts even while switcher is disabled. */
	ldd XL,Y+CONTEXT_STACK_PTR
	ldd XH,Y+CONTEXT_STACK_PTR+1
	in tmp_reg,_SFR_IO_ADDR(SREG)
	cli
	sts avr_thread_active,YL
	sts (avr_thread_active)+1,YH
	/* Load new stack pointer. */
	out _SFR_IO_ADDR(SPH),XH
	out _SFR_IO_ADDR(SPL),XL

	/* Tell isr it's okay to switch again. */
	lds XL,avr_thread_disabled
	dec XL
	out _SFR_IO_ADDR(SREG),tmp_reg
	sts avr_thread_disabled,XL

	/* Restore SREG. */
	pop tmp_reg
        cbi tmp_reg,SREG_I
	out _SFR_IO_ADDR(SREG),tmp_reg

	/* Restore all registers. */
	POP_ALL

	reti
