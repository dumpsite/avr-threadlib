
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/signal.h>
#include <avr-thread.h>

// Thread stack
uint8_t fn_stack[128];
// Thread context
avr_thread_context fn_context;
// Thread code
void fn(void)
{
    uint8_t state = 0;
    for (;;) {
        if (state)
            PORTB &= ~0x02;
        else
            PORTB |= 0x02;
        state = ! state;
    }
}

int main(void)
{
    // Setup port B as all output.
    outp(0xff, PORTB);
    outp(0xff, DDRB);

    // Setup timer 2 mode.  Include reset on overflow bit.
    // Approximately 1.008 kHz for 4 MHz crystal.
    outp(BV(WGM21) | BV(CS21) | BV(CS20), TCCR2);
    outp(62, OCR2);
    outp(0, TCNT2);
    sbi(TIMSK, OCIE2);

    // Initialize avr-thread library.
    avr_thread_init();
    sei();
    // Start new thread
    avr_thread_start(&fn_context,
                     fn, fn_stack, sizeof(fn_stack));

    uint8_t state = 0;
    for (;;) {
        if (state)
            PORTB &= ~0x01;
        else
            PORTB |= 0x01;
        state = ! state;
    }
}

// Task switcher
void SIG_OUTPUT_COMPARE2(void) __attribute__((naked));
void SIG_OUTPUT_COMPARE2(void)
{
    sei();
    avr_thread_isr_start();
    switch_count++;
    avr_thread_isr_end();
}
