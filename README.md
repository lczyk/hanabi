# hanabi

ruby reimpl of [hanabi](https://esolangs.org/wiki/Hanabi), a stack-based 2D esolang by [User:Ellie](https://esolangs.org/wiki/User:Ellie) (2018). name = japanese for _firework_. turing complete.

original ruby impl lived at <https://github.com/elyatai/hanabi> -- now dead. this repo reconstructs an interpreter from the wiki spec alone. all credit for the language design goes to Ellie; bugs in this impl are mine.

## usage

```
ruby hanabi.rb <file.hnb>
```

examples in the repo:

- `hello.hnb` -- prints `Hello, world!`
- `fib.hnb` -- prints fib(0)..fib(20). bounded loop variant (original on wiki ran forever)
- `prime.hnb` -- prompts ` >`, reads n, prints `1` if prime else `0`. handles n<=2 via explicit guard
- `fizzbuzz.hnb` -- prints fizzbuzz 1..N

helper scripts:

- `dump.rb <file.hnb>` -- print opcode table for a program
- `optim.rb [--iter N] [--stagnation N] [--bt-limit N] [--seed N] [--verbose] <file.hnb>` -- repack dots into a smaller (h*w) grid; writes result to stdout, progress to stderr. handles SIGTERM cleanly

## encoding

each instruction = one `.` char. count whitespace in 4 dirs (up/down/left/right) until non-whitespace (any non-space char, incl. another `.`). the 4 counts `(U, D, L, R)` form the opcode. dots execute in row-major order (top-to-bottom, then left-to-right within row).

spec says missing non-whitespace in any direction = syntax error. this impl enforces that strictly -- a dot reaching the grid edge in any direction raises.

## op table

| #  | U | D    | L | R    | op |
|----|---|------|---|------|----|
| 1  | 0 | n    | 0 | 0    | push n |
| 2  | 0 | n    | 0 | 1    | push ASCII codes of digits of n |
| 3  | 0 | 0    | 0 | 2    | input one byte |
| 4  | 0 | 0    | 0 | 3    | input one number |
| 5  | 0 | 0    | 0 | 4    | input one line |
| 6  | 0 | 1    | 1 | 0    | push stack length |
| 7  | 0 | 0    | 1 | 0    | swap top two |
| 8  | 0 | 0    | 1 | 1    | reverse entire stack |
| 9  | 0 | 0    | 1 | n>=2 | reverse top n |
| 10 | 0 | 0    | 2 | 0    | swap top two |
| 11 | 0 | 0    | 2 | 1    | rotate entire stack up |
| 12 | 0 | 0    | 2 | n>=2 | rotate top n up |
| 13 | 0 | 1    | 2 | 0    | swap top two |
| 14 | 0 | 1    | 2 | 1    | rotate entire stack down |
| 15 | 0 | 1    | 2 | n>=2 | rotate top n down |
| 16 | 1 | 0    | 0 | 0    | pop; print as ASCII |
| 17 | 1 | 1    | 0 | 0    | print entire stack as ASCII |
| 18 | 1 | c>=2 | 0 | 0    | print top c items as ASCII |
| 19 | 1 | 0    | 0 | 1    | pop; print as number |
| 20 | 1 | 1    | 0 | 1    | print entire stack as numbers |
| 21 | 1 | c>=2 | 0 | 1    | print top c items as numbers |
| 22 | 1 | 0    | 0 | 2    | print newline |
| 23 | 1 | 0    | 1 | 0    | pop and discard |
| 24 | 1 | 0    | 1 | c    | pop and discard c items |
| 25 | 1 | 0    | 2 | 0    | clear stack |
| 26 | 2 | 0    | 0 | 0    | duplicate top |
| 27 | 2 | 0    | c | n    | duplicate top n items c times |
| 28 | 2 | 1    | 0 | 0    | == |
| 29 | 2 | 1    | 1 | 1    | != |
| 30 | 2 | 1    | 1 | 0    | < |
| 31 | 2 | 1    | 2 | 0    | <= |
| 32 | 2 | 1    | 0 | 1    | > |
| 33 | 2 | 1    | 0 | 2    | >= |
| 34 | 2 | 2    | 0 | 0    | addition |
| 35 | 2 | 2    | 0 | 1    | subtraction |
| 36 | 2 | 2    | 1 | 0    | multiplication |
| 37 | 2 | 2    | 1 | 1    | division |
| 38 | 2 | 2    | 2 | 0    | exponentiation |
| 39 | 2 | 2    | 2 | 1    | logarithm |
| 40 | 2 | 2    | 0 | 2    | modulo (impl quirk: `a % 0` pushes `a` instead of crashing) |
| 41 | 2 | 2    | 1 | 2    | integer division |
| 42 | 2 | 2    | 2 | 2    | divmod |
| 43 | 2 | 3    | 0 | 0    | logical not (push 1 if popped is 0 else 0) |
| 44 | 3 | n    | 0 | 0    | set label n |
| 45 | 3 | n    | 0 | 1    | pop; jump to label n if nonzero |
| 46 | 3 | n    | 1 | 0    | pop; jump to label n if zero |
| 47 | 3 | n    | 1 | 1    | unconditional jump to label n |
