AVR Threads Library
===================

The AVR Threads Library provides basic preemptive multitasking/multi-threading to the Atmel AVR family of microcontrollers. It is written mostly in C with some assembly language. It implements a simple round-robin style task switcher.
This library provides basic thread start and stop functions, a couple of flavors of mutual exclusion semaphore, and events to help synchronize threads.
The library builds for three AVR families which include the ATmega128, the ATmega103, and the AT90S8515 and AT90S8535. It should be relatively easy to modify the make files and source to build the libraries for other AVR microcontrollers.
I have released this code under the GNU Lesser General Public License with the hope that others might find it useful.

Dean Ferreyra <dean@octw.com>
