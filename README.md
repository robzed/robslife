Rob's Life
==========

Faster pixel-based Conway's game of life.
For the Sinclair ZX Spectrum.
Written by Rob Probin, November 2020.

This life writes back to the screen as it's processing - which means we do most 
reading and writing from upper RAM.

BACKGROUND
----------

There are a whole bunch of implemnentations of Conway's Game of Life for the 
Sinclair ZX Spectrum. For details on Conways Game of Life see 
https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life

After a conversation with a nice chap on a the Spectrum Next Facebook group, I ended up 
playing with two other pixel life's:

Macro-Life (1986) by Toni Baker  - which takes about 10.5 seconds full screen (192 lines).
Life (1988) by Paul Hiley - which takes about 3.5 seconds for 2/3 the screen (128 lines).

So that got me thinking - surely we can do it faster.


ALTERING THE AMOUNT OF SCREEN PROCESSED
---------------------------------------

POKE 55556, number-of-lines
POKE 55558, start-line.

Start-line is 0 to 191.
Number of lines is 1 to 192.
Start-line plus number-of-lines should *never* be more than 192.

IMPORTANT FILES
---------------

* tape_wrapper.tap - you can load this into ZX Spectrum emulator
* robslife.asm - this contains the actual core Life program in Z80 Assembler.
* tape_wrapper.asm - make a single test BASIC program with a glider.

With tape_wrapper.tap type 'GO TO 40' to step the next frame.

MACHINE CODE
------------

Normally loaded at 55555.

Execute address 55555
    e.g. RANODMISE USER 55555

Screen copy: 49152 (although there is a 32 byte blank line buffer below this!)

CLEAR 49000
    actually could be CLEAR 49152 - 32 maximum minimum

There is a small amount of space above the code, but not much.


Simple example program 
----------------------

    10 CLEAR 490000
    20 LOAD "" CODE 55555
    30 PLOT 2,175: PLOT 2,174: PLOT 2,173: PLOT 0,174: PLOT 1,173
    40 RANDOMIZE USR 55555



EXISTING IMPLEMENTATIONS
------------------------

I disassembled the machine code of both of the MAcro-Life (1996) and Life (1988).

It's obvious that Macro-Life is a nice robust piece of code. Not optimal, but 
ok. And structured for ease of writing and developing. 

Life (1988) was more optimised - in fact, the core piece of code that 
calculates a pixel is nice and compact - the each pixel needs to examine the 8 
neighbours and this is about two instructions per pixel examined - pretty 
impressive. 

Then a few instructions to decide if it's two or three, then loop back to the 
start after doing a bit more work. To get two instructions per neighbour pixel, 
it needs to unpack from bits to bytes - so we have a byte per pixel. The code 
does this on a per line basis, and has to do this for the line above and line 
below - although obviously the program only needs to do one new line per line, 
it can copy the other two. Then it needs to also re-pack bytes back into bits.

Even so - there is no much more that could be taken out of this, to be honest.

Still... surely we can do better? 3.5 seconds for 2/3 the screen. 
See 'PROCESSING REQURIRED' for how much processing needs to be done.
See 'OPTIMISATION APPROACH' for how we can take some cycles out.


References:
https://spectrumcomputing.co.uk/entry/25833/ZX-Spectrum/Macro-Life
https://spectrumcomputing.co.uk/entry/14096/ZX-Spectrum/Outlet_issue_009
https://spectrumcomputing.co.uk/entry/21938/ZX-Spectrum/Life


PROCESSING REQUIRED
-------------------

For a start you need copy the screen either before or afterwards. Because you 
can't accurately calculate each pixel to the rules if pixels are changing around
because each next pixel state requires neighbours pixel state. 

There are 49152 pixels on a Spectrum screen - 255 * 192. 
For each pixel you need to check 8 pixels around. that's 393216 pixels to be 
examined.

From this we can guess how many clock cycles is required on average per screen pixel:
(let's assume 3.5MHz).
Macro-Life = 10.5/49152 * 3500000 = 747 cycles per pixel.
Life (1998) = 3.5 / 32768 * 3500000 = 343 cycles per pixel.

All instructions takes at least 4 cycles, and mostly more.


OPTIMISATION APPROACH - SCREEN COPY
-----------------------------------

For a start the screen copy uses LDIR - as most people do. This takes 21 cycles 
per loop, 

LDI only takes 16 cycles, so with loop unrolling we get this down to about 16.3 
cycles - total time to 29ms from about 37ms (ignoring ULA cycle steaming 
from lower RAM).

Theoretically it's possible to get


OPTIMISATION APPROACH - LIFE PIXEL PROCESSING
---------------------------------------------

Secondly, rather than deal with each neighbour at a time, perhaps we can count
multiple pixels above, current and below lines. We can then step along the 
byte of 8 pixels.

We take this approach - but the code is much longer. We try to keep the pixel 
data in registers, and the pointers/address of the pixel data on the stack.


FUTURE OPTIMISATIONS
--------------------

Because of the Spectrum screen layout, the current code copies the entire screen 
even if only part of the screen is being processed. This could be fixed, athough
the saving is not massive - at most 29ms per pass.

We also process all pixles equally. However, most of the time, pixels and their
neighbours are blank. The trade off might be worth it?


THANKS TO
---------

Henk de Groot - for getting me looking at this - after he posted about a 
video about a computer written in Life. Life is Turing complete(!)
https://www.facebook.com/groups/specnext/permalink/1300443853646265/

Pages with lots of info ... too many to list ... here are a few.
  https://www.spectrumcomputing.co.uk/forums/viewtopic.php?t=2504
  https://wikiti.brandonw.net/index.php?title=Z80_Optimization
  https://retrocomputing.stackexchange.com/questions/4744/how-fast-is-memcpy-on-the-z80
  https://zxsnippets.fandom.com/wiki/Clearing_screen

ZX Spectrum Next Team, Sinclair, Zilog and a million others.

Kio for ZASM and ZXSP. (Thanks for your email about getting errors out of 
ASM loading in ZXSP!)

And of course, John Conway himself. December 1937-April 2020. 
https://en.wikipedia.org/wiki/John_Horton_Conway 
May you rest in piece.


