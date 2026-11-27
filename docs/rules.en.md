# Nuances and decisions

> English translation of [the Russian original](rules.md). In case of disagreement, the Russian version is authoritative.

> **Historical document.** This contains notes from the early stages,
> including plans for C emission and `kraftc`. Current decisions —
> `docs/decisions.md`, the list of functions — `docs/builtins.md`, libraries —
> `docs/libs.md`, the guide — `README.md`. This file is not updated;
> the point below about `std/math` was revised by D120.

## Current as of 0.5.0

- All top-level declarations of a module are importable via
  `import_file` / `from_file` / `import_lib` / `from_lib`; the `_` or `__` prefix
  is only a convention for the reader; it does not create privacy.
- A `dict` key is `str` or `flint`. A bare name and quotes specify a string key;
  `bool`, `NONE`, collections, and models cannot be keys.
- The standard library is only `std/fos` and `std/cli`, baked into the
  distribution. `std/fs`, `std/json`, `std/file`, `std/math`, `clamp`, `lerp`
  and `is_even` are not shipped; `json_parse` and `json_stringify` are internal.
- `fib` and `factorial` are core built-in functions.
- The manifest is `kraft.json` + `kraft.lock`, dependencies are called `deps`.
  The canonical command is `kpm init venv`, not `kpm venv init`.

> **Current as of v0.1 (LuaJIT).** The source of truth is `docs/decisions.md`.
> Sections about the C backend (`kraftc`, `krt.c`, `cc`, C backend words, C emission)
> are history and do not apply to the current implementation. They are kept as notes
> for the future (native backend v1.0).

README is the language spec for the programmer. This file covers internal nuances and
decisions for those writing the compiler. If a nuance matters to the reader, it
moves to README; only what is needed for implementation belongs here.

New language decisions are recorded here and in README **before the code**, not after.

## Error format — with caret, expected / found

```
TYPE_ERROR: имя_файла:12
    12 | flint x = "текст"
                         ^ expected declaration of 'x': type flint, found str
```

- first line: **category: file:line number**;
- then the code line itself with its number;
- the caret `^` exactly under the error location;
- the explanation is in English, in two parts: `expected X` (what was expected,
  in yellow) and `found Y` (what was found, in red), separated by a comma;
- colors only when stderr is a terminal; otherwise output is clean — against it
  xkraft is compared with kraftc byte-for-byte.

Implementation nuances:

- in the parser, found is **formed automatically from the current token**
  (`fail`: name, number, keyword with text, "end of line"…);
  it can be set manually via `fail2` (occupied name, growth word);
- in the analyzer, expected is a ready-made string (often via a local buffer),
  found is a format with names/types;
- count columns in **characters, not bytes** (Cyrillic is two bytes,
  otherwise the caret shifts);
- a tab inside a line: for now count it as one character, clarify during implementation;
- in v0, categories are only labels when printed, no handling yet;
  `try` / `trigger` / `finally` / `panic` are the growth stage;
- runtime errors are a category (red on TTY) + English text,
  without a caret; embedding positions is the growth stage.

Error categories (full list for reference):

`SYNTAX_ERROR`, `NAME_ERROR`, `REDECLARE_ERROR`, `CONST_ERROR`, `TYPE_ERROR`,
`SCOPE_ERROR`, `ARGCOUNT_ERROR`, `VALUE_ERROR`, `CONCATENATE_NOT_SUPPORT`,
`FILE_ERROR`, `TYPE_MISMATCH_ERROR`, `PANIC_ERROR`, `RUNTIME_ERROR`,
`GENERATE_ERROR`, `ASSERT_ERROR`, `EXPECT_ERROR`.

## Names: what is not allowed

The name of a variable, function, parameter, method, field, or model cannot be:

- a language word (`if`, `str`, `func`, `model`, `try`…);
- a name from the built-ins (functions, type methods) — see README,
  «Зарезервированные имена»;
- **a backend word**. Our backend is C, so C words are also forbidden:
  user names go into the generated code as-is, while runtime names
  are protected by the `krt_` prefix. The list (fixed):
  types and qualifiers — `int`, `char`, `double`, `float`, `void`,
  `long`, `short`, `unsigned`, `signed`, `const`, `static`, `extern`,
  `struct`, `union`, `enum`, `typedef`, `sizeof`, `volatile`, `register`,
  `auto`; C control words — `switch`, `case`, `default`, `do`, `goto`;
  library — `malloc`, `free`, `calloc`, `realloc`, `memcpy`, `memset`,
  `strlen`, `strcmp`, `printf`, `fprintf`, `sprintf`, `fopen`, `fclose`,
  `main`, `NULL`, `size_t`, `FILE`.
  (Language words with the same names — `return`, `for`, `if`, `while` — are cut off
  by the lexer itself: they are tokens, not identifiers.)

A violation is `REDECLARE_ERROR` («имя занято»), as is a repeated declaration
or a match with a built-in: an error at declaration, and the message lists
the occupied names. The exception is language words and `show`/`input`: these are tokens,
the parser already gives them the name position, the category is `SYNTAX_ERROR`, and the text is the same
(«имя занято: show — встроенная функция»).

## v0 analysis: categories

- `NAME_ERROR` — reading an undeclared name (visible only after
  declaration); calling an unknown function; a nonexistent method on a
  known type; a function name not in Latin letters ("ends up in the generated
  code" — cannot be generated → `GENERATE_ERROR`);
- `REDECLARE_ERROR` — repeated declaration, «занято» (built-ins, backend
  words, function/variable conflict); a `for` loop variable is
  **scope shadowing**: repeated `for i` is legal, after the loop the name
  rolls back (to the outer one, if the loop shadowed it); occupied words
  (function/built-in/type/C word) are an error for the loop too;
- `CONST_ERROR` — assignment and compound assignment to a name written
  entirely in uppercase (`MAX`, `MAX_SIZE`);
- `TYPE_ERROR` — the type of a declaration/assignment/argument/result
  of a function did not match; arithmetic with non-numbers; compound assignments not
  with numbers; a slice not of a string/list; a dict key in `[]` that is not a literal;
  `is` with an unknown type; `froz` and other "growth stage" features in type position;
- `CONCATENATE_NOT_SUPPORT` — `+` if one of the operands is exactly a string;
- `SCOPE_ERROR` — a file variable's name inside a function (v0 has no `glob`
  — pass it as an argument);
- `ARGCOUNT_ERROR` — arity of one's own function, a built-in, or a method;
- `SYNTAX_ERROR` — `break`/`continue` outside a loop, `return` outside a function
  (the syntax allows it, generation does not);
- unknown expression type (a function call without `->`, a dict element) —
  we skip the type check: the language has no type inference.

## self in methods

Two sections of the spec contradicted each other; the detailed interpretation is correct:

- fields are created **only by the constructor**: `self(имя, ...)` positionally by
  parameters or `self.поле = значение`;
- in a method, a field is written **`self.поле`**; a bare field name is an error;
- a field cannot be created from a method — only written to an existing one;
- `_` / `__` before a name is only a hint to the reader: accessing such
  a field is allowed, there is no privacy;
- a local variable cannot have the same name as a field;
- a parameter with a field's name is a parameter (it does not shadow the field);
- `return self` is allowed — for chaining.

```kraft
model Hero:
    construct(str name, flint hp):
        self(name, hp)          # создаёт поля name и hp

    method take_damage(flint dmg):
        self.hp -= dmg          # поле — только через self
        # hp -= dmg             # ошибка: голое имя поля не видно
```

`self(name, hp)` creates fields by parameter names. Dot assignment
(`self.hp = 100`) changes an already existing field; it cannot create a new one.

## Not in v0 (growth stage and beyond)

The baseline v0 compiler does not include:

- **models** (`model`, `construct`, `method`, `self`, `init`,
  static fields) — a whole section of the spec, but for the v0 goal (lexer → parser
  → C emission → binary → examples) functions and collections are enough. They are added
  step by step: fields → `construct` → methods → `init` → printing;
- **imports** (`import_file`, `from_file`, `import_lib`, `from_lib`) —
  v0 works with a single file;
- **`glob`** — functions in v0 are fully isolated;
- **error handling** (`try`, `trigger`, `finally`, `panic`) — in v0
  error categories exist only as labels when printed;
- **higher-order functions** (`map`, `filter`, `reduce`) — passing
  a function by value is the hardest part for the parser;
- **`froz`** — frozen lists;
- **`assert` / `expect`** — will appear together with tests (after the baseline);
- **external methods** (`method Тип.имя()`) and **named arguments**
  (`init(...)` is the only place where they exist).

## Semantics: short rules

- `list`, `dict`, `froz` are passed **by reference**: `b = a` does not copy,
  a slice copies;
- truthiness: `0`, `""`, `[]`, `{}` are **true**; only `NONE` and
  `FALSE` are false (deliberately not like Python);
- a missing dict key gives `NONE` and is not an error (both indexing and `take`);
  `remove` of a missing key → `FALSE`;
- an index out of list bounds → `VALUE_ERROR`; slice step `0` →
  `VALUE_ERROR`; a reverse range → an empty list;
- no concatenation: `"a" + "b"` → `CONCATENATE_NOT_SUPPORT`, only
  interpolation and `list.join`;
- there is one numeric type — `flint`, which is also fractional (`7 / 2` → `3.5`);
  there is no separate `float`, `avg` returns `flint`;
- `sort`/`reverse` are functions that return a **new** list (via
  assignment); `add`/`del`/`remove` mutate the collection in place, as does
  the function `clear(coll)` (list/dict, returns `NONE`);
- for dict: `add(ключ, значение)` — add/update, `remove(ключ)` —
  delete, `take(ключ)` — by a key variable; there is no `set` method;
- for strings: more methods than in the old spec (`triml`, `trimr`,
  `count`, `remove(подстрока, количество)`), strings have no `join`;
- a variable is visible only **after** declaration (reading earlier —
  `NAME_ERROR`); an unexecuted block leaves the name with value `NONE`;
- a parameter shadows a field;
- `for` loop: a range without `in` (`for i 5..9:`), iteration with `in`
  (`for x in список:`); step `0` is an empty loop, not an error;
- the "200 names per file" limit was a limit of the old backend; for C we
  **do not introduce** it;
- `is_list`/`is_dict` are unnecessary — type checking is the `is` operator;
- an empty return is `return:`;
- a function call is a statement: `exit(2)`, `die("х")`, `f()` (an extension
  of stage 4: without it one can write neither `exit(main())` nor procedures; methods
  `a.b()` were already statements);
- text whitespace between substitutions in a template is preserved:
  `show($(x) $(y))` → `1 2` (phase 4 fixed parse_template — previously
  the space between two substitutions was collapsed);
- **limitation**: `\"` inside a show template is unreliable (the parser's escape-
  branch consumes two tokens, the quote opens a string). Move a quote
  in a template into a variable: `str q = "\""`, then `$(q)текст$(q)`;
  in ordinary strings `\"` is fine (there the lexer's escape rules apply).

## v0 emission: decisions

The backend is C11. The emitter writes one self-contained file `файл.c`: the runtime
is embedded via `#include` (`src/krt_all.h`, the path is baked into kraftc at build
time — acceptable for the seed stage; portability will be resolved with the self-binary).
`kraftc файл.kraft` places the `файл` binary next to it (calls `cc`);
`--emit` is the C file only, without cc. cc errors are shown as-is.

- all values in the generated code are `KVal` (tag + union): a variable
  of any category may turn out to be `NONE` (an unexecuted block, `flint x =
  NONE`), so neither C types nor "static" checks save us;
- variables are declared at the start of their function (= `NONE`), assignment is
  a struct copy; `list`/`dict` share a pointer, a slice copies;
- names: functions — `kf_<имя>` (Latin letters guaranteed by analysis), variables
  — `kv_N` in declaration order within the scope: a C identifier need not
  accept UTF-8, and original names never appear in the code;
- arithmetic — runtime functions with checks: non-number (including `NONE`)
  → `TYPE_MISMATCH_ERROR`; division by 0 and negative exponent →
  `VALUE_ERROR`; `//` is floor (Python), `%` takes the divisor's sign;
- comparisons `==`/`!=` — any types: different types — `FALSE`, `NONE == NONE`
  — `TRUE`; `<` `<=` `>` `>=` — flint with flint, str with str (memcmp over
  UTF-8 bytes), otherwise `TYPE_MISMATCH_ERROR`;
- comparison chains expand into AND, the middle operand is emitted twice
  (the spec promises this); `AND`/`OR` are lazy (C `&&`/`||` over
  truthiness), result `bool`; `NOT` only over `bool`;
- ordinal comparisons are emitted as `krt_ord(a, b, "op") X 0`, where `X` is
  strictly its postfix: `<` → `< 0`, `>` → `> 0`, `<=` → `<= 0`,
  `>=` → `>= 0` (`krt_ord` returns −1/0/1). There was a bug: `>` had
  `< 0` (like `<`), so `>` in conditions always gave `FALSE` for
  `a > b` and worked like `<`; caught by the stage-4 lexer spike, fixed;
- truth: not `NONE` and not `FALSE` (0, "", [], {} are truths);
- `show` collects text into a buffer and prints it as one line; value
  format — as in the "Types" section: a string as a value without quotes, but
  inside a list/dict value — in quotes; `NONE` is printed as `NONE`;
  number: exact integer — without `.0`, otherwise up to 14 significant digits;
- `input`: the prompt is printed without a newline; first the `# stdin:` lines
  (line-by-line scan of the source, indentation allowed, spaces after
  `:` are the separator, an empty tail is an empty string), then real stdin;
  Ctrl-D → `""`;
- indexing: 0-based, a negative index counts from the end, going out of bounds →
  `VALUE_ERROR`; `s[i]` is by UTF-8 characters; a dict key is a string
  (otherwise `TYPE_MISMATCH_ERROR`), a missing key — `NONE`;
- slices: open bounds, negative ones count from the end, step 0 →
  `VALUE_ERROR`, a reverse range → empty; string → string, list →
  list; `for` with step `0` is an empty loop (not an error, decision above);
- `for` range: bounds and step are evaluated once (side effects);
  step < 0 — comparison via `>`, the right bound is exclusive;
- `for-in` — a runtime iterator over list/dict; other types →
  `TYPE_MISMATCH_ERROR`; for a list, the second name is `NONE` (two names
  are defined only for dicts);
- methods — a runtime dispatcher `krt_method(получатель, "имя", аргументы,
  n)`: uniform even with an unknown static type;
- built-ins — direct `krt_len(x)`, `krt_sum(xs)`, etc.; `min`/`max` —
  one form `max(список)` and two forms `max(a, b)`, arity 1..9;
- `time_ms()` — processor time; `args()` — argv of the compiled binary
  in full (including its name, like "path to source" in the old spec).

Open minor points from `builtins.md` are settled as follows: `list.replace(a, b)` —
replaces the first occurrence of a value (in parallel with `remove`); `upk(coll)` —
elements in print format without outer brackets, separator `", "`.

## Seed version (v0) is frozen

Before stage 4 (the `xkraft` self-binary), the v0 subset was frozen: kraftc is
the reference that `xkraft` must reproduce. What is in the freeze:

- all syntax and types from README: `str`/`flint`/`bool`/`NONE`/list/dict,
  indentation, templates `$имя`/`$(выражение)`, `show`/`input` (+ `# stdin:`);
- operators: arithmetic (`//` floor, `%` with divisor sign, `**` right-associative),
  comparisons (chains via AND, middle operand twice), `AND`/`OR`/`NOT`,
  `is`;
- `while` loops / `for` range / `for-in` (+ break/continue), functions
  `func ... -> тип` and `return:` (empty return);
- indexing (negative indices, a dict literal key via `[]`),
  slices `a..b..шаг`, all string/list/dict methods and all built-ins;
- errors: categories and caret format from `docs/rules.md`; runtime errors —
  `TYPE_MISMATCH_ERROR` / `VALUE_ERROR` / `FILE_ERROR` / `RUNTIME_ERROR`
  (category + text, no position).

Decisions made at freeze time:

- `min`/`max` accept **any** number of arguments (1 — over a list, ≥2 — over
  numbers); arity in the analyzer is 1..9, the runtime imposes no upper limit;
- `round` — as in C: halves are pulled away from zero (`round(2.5)` → `3`,
  `round(-2.5)` → `-3`); the spec does not specify, the mathematical convention was taken;
- a bare dict key in `[]` (`user[имя]`) is a literal **only** for a dict with
  a known type; after the first index the type is unknown, so for
  `d2[y][z]` the inner key is written as a string (`d2["y"]["z"]`);
- `for i` is **scope shadowing**, not a declaration: repeated `for i` in the same
  scope is legal (each loop gets its own C name `kv_N`), after the loop
  the name rolls back to the outer value (or disappears if there was none).
  Occupied words (function/built-in/type/C word) are an error here too.

Verified at freeze time: end-to-end tests (slices, all built-ins, edges
of strings/types/NONE, empty collections), runtime errors (division by zero,
negative exponent, `NONE + 1`, index/slice out of bounds, incomparable
comparisons, `sum` of strings), both references from tour §18 (calculator, word
counter); the generated C is clean under ASan/UBSan. Stage 3 is closed.

## Porting the lexer to Kraft (xkraft, step 2)

`xkraft/xkraft.kraft` is a full port of `src/lexer.c`: frames (TEXT/EXPR),
INDENT/DEDENT, multiline `---`, all operators. `--tokens` parity
with kraftc is byte-for-byte on all fixtures (including the caret error
format). v0 limitations discovered during the port:

- **literals do not carry over**: strings/lists/dicts — only on one
  line; operator tables are built as flat lists of pairs
  (`["..", "DD", ...]`);
- **`if`/loop bodies share one scope** (the analyzer has no
  nested scopes): variables from consecutive block bodies
  conflict → names have to be spread out (`o3`/`o2`, `k3`/`k2`);
- **assignment to an element is forbidden** ("an element is changed by a method") —
  lexer state lives in a dict, updated via `add(ключ, значение)`;
- a `$` literal in a string — only via escape `"\$"`; the characters `|`, `^`,
  `#` in a show template are not tokens and are shown via a variable;
- strings are indexed by UTF-8 characters — positions (line/col) in
  characters match the C lexer without extra effort.

Performance of the naive port: xkraft tokenizing itself —
~2 s; optimization (not creating tables on every call) is the growth stage.

## Error format in xkraft (step 3)

`set_err` now has two parts: `set_err(st, exp, line, col, found)` —
the texts **match byte-for-byte** with `src/lexer.c`. `report_lex` prints
the kraftc format: the category in red, `expected X` in yellow, `found Y`
in red — colors only when `is_tty()` (a built-in that checks stderr);
with redirection the output is clean. kraftc ↔ xkraft parity has been checked
both in a pipe and under `script` (a terminal) — byte-for-byte.

Port nuances:

- `found` for "unknown symbol" and "after `$`" is the **first byte**
  of the character (`c[..1]`): the C side prints it the same way via `%c`;
- temporary `fnd1`/`fnd2`/`fnd3` in `lex` — names were spread out because of
  the shared scope of block bodies (see step 2);
- colors in the source use escape `"\e[31m"` (a new `\e` character escape).

## Porting the parser to Kraft (xkraft, step 4)

`xkraft/xkraft.kraft` is a full port of `src/parser.c`: the AST is dict/list-based
(a node is `{kind, line, col}` plus optional fields; a missing
key reads as `NONE` and is not printed), parser state is a dict
of errors (`has_err`/`exp`/`found`/`err_line`/`err_col`, the first wins),
a statement dispatcher, `ast_dump` and `--ast`. Step 4a — the skeleton and atoms,
step 4b — eight expression levels (`e_or`..`e_unary`), postfix
(`index_tail`/`arglist`/`postfix_from`: index, slice, call, field,
method; a call is only directly by name) and templates (`subst`,
`parse_template`, `parse_string` for STRTEXT/DOLLAR..STREND).

`--tokens` and `--ast` parity with kraftc is byte-for-byte: stdout, stderr
and the return code are compared **separately per stream**; checked
on ~50 positive and negative fixtures, on the self-parser (xkraft
parses itself — the md5 of the outputs matches) and in TTY (colors under `script`).
Errors go to stderr via the built-in `show_err` (as in kraftc).

v0 bugs and nuances found during the port:

- **the v0 `parse_template` bug is fixed** (parser.c, commit a4b8e64):
  a literal `)` right after `$(...)` with an unpaired `(` in the text
  of the template was lost — RPAREN was excluded from text gathering (`text_on` was not
  enabled, flush did not happen). Fix: RPAREN takes part in
  text gathering, an empty flush is safe (guard `b1 > b0`). Step 4b ports
  the already fixed logic;
- `trunc64` ("%.64s" for found): C cuts **bytes**, xkraft cuts characters;
  it differs only on strings with multibyte characters in the first
  64 bytes (not found in spec fixtures, does not affect the parity
  denominator);
- a `$` literal before a string's closing quote (`"..."`) is read by the lexer
  as a substitution — in Kraft source write `"\$"`
  (decode_text will return `$`);
- `report_lex` in xkraft: the caret indent cannot be cut from a fixed
  string — for `col > 13` the position was wrong; it is built by a loop, like C's `%*s`;
- variable names inside a function are spread out for uniqueness
  (shared scope of block bodies, see step 2) — in the port these are `i_e0`/`i_ec`,
  `t1`/`t2`, `l1`/`n1`;
- `upk`: the code (`krt_upk_of`) and the docs diverged on the example in
  `docs/builtins.md` (old dump with a space) — the example was fixed
  to the separator `", "` (the decision stayed with the runtime).

Performance of the naive port: xkraft parses itself in ~22 s
(kraftc — 5 ms; strings are concatenated character by character, each operation —
a new string). This does not concern the growth stage: self-hosting is a one-time
build, ~22 s is acceptable.

## Porting C emission (xkraft, step 6)

`emit_c(body, src, cpath, krtp)` is a full port of `src/emit.c`: names
`kv_N`, deferred declarations (`em_collect` lifts block declarations
to the top of the function), shadowing of loop variables (`em_var_shadow`),
prototypes, `main` with stdin strings. The text is accumulated in a list and
joined with `join("")` at the end; writing is `write_file`. Emitter state
is a dict, updated with `add`/`del` (assignment to an element in v0
is forbidden).

Nuances inherited from kraftc byte-for-byte: doubled indentation of the line
`{` for for-loops (`ind_` + `w` in C), a double pass over the function body
(collect → decls → stmts), a middle link of a comparison chain
evaluated twice, `krt_num(1)` instead of a missing step.

**`.c` parity is functional** (step 6 decision). Two classes
of text divergence that cannot be fixed in v0 — the binaries they produce are identical:

1. **non-ASCII and control bytes in strings**: kraftc writes octal
   (`\320\277`, `\033`), xkraft writes raw bytes. In v0 the byte value
   is not observable: there is no `ord`/`chr`, string indexing and slices are
   character-based, comparisons are only lexicographic (from the character
   `€` one cannot obtain 226 — provably);
2. **numeric literals**: kraftc writes `%.17g` (the exact 17-digit
   representation of a double: `0.1` → `krt_num(0.10000000000000001)`),
   xkraft writes the normalized text of the source literal (`08` → `8`,
   `.5` → `0.5`); exact expansion of a double into a decimal fraction
   requires bignum — unavailable in v0.

Both classes change only the `.c` text: the original literal text goes
through `strtod` to the same double. Byte parity of `.c` is preserved for
ASCII programs with integer literals and fractions exact in binary
(`3.5`, `0.25`).

Verification of step 6:

- `.c` kraftc ↔ xkraft: 5/8 valid fixtures byte-for-byte, 3 DIFF —
  only the classes above;
- binary behavior (stdout, stderr, rc) kraftc ↔ xkraft ↔
  self-binary: 8/8 identical;
- self-binary (xkraft.c from xkraft, built with cc): `--tokens`/`--ast`
  md5 with kraftc, full parity 50/50, ASan/UBSan clean;
- self-emission is deterministic: the `.c` produced by xkraft from
  `xkraft.kraft` equals the `.c` from the self-binary byte-for-byte —
  a fixed point (gen3 = gen2); with the `.c` from kraftc — only two
  documented classes (see above), 28 lines;
- self-emission of xkraft.kraft: ~80 s (lex+parse+analyze+emit).

Other:

- the runtime path is baked into `xkraft.kraft` as a string — just like
  `-DKFT_KRT` in kraftc via Makefile; in the growth stage it may become
  a flag;
- xkraft's default mode now writes `.c` silently (a line like
  `xkraft: записан …` is a step 7 decision);
- lexer fix (commit 47e1470): C accepts a name with any byte
  `>= 0x80`, not only Cyrillic; `DEL` (0x7F) in `is_name_start`
  passes as a name start — in v0 it cannot be distinguished from a multibyte character
  (there are no characters with a first byte of 0x80..0xC1),
  it is the invalid-input class.

## CLI parity (xkraft, step 7)

`xmain` mirrors `src/main.c` 1:1: the flags `--tokens`/`--ast`/`--emit`
in any order (before or after the file), an unknown flag →
`xkraft: unknown flag: X` rc 2, a second file → `xkraft: specify only
one file` rc 2, no file → usage rc 2, `FILE_ERROR: cannot open
file: X` rc 1. A lone `-` is a file name, not a flag (as in C).
Mode priority: tokens > ast > emit (as in the C if/else chain).

xkraft default mode == `--emit`: writes `.c` and prints
`xkraft: записан <cpath>`; kraftc's default is a build via cc and
`kraftc: собран <binpath>` (running cc is the shell's job, option A).
`die()` was removed — CLI messages and return codes go through `show_err`
and `return` (1 — file/compilation errors, 2 — CLI).

Check (`/tmp/opencode/p7/cli_parity.sh`): a 16/16 matrix —
stdout/stderr/rc, messages are compared with the prefix
`kraftc` → `xkraft` replaced; `.c` in `--emit` byte-for-byte; the default-mode
line format is exact. The self-binary repeats the CLI (usage, unknown
flag, emit — `.c` byte-for-byte). Regressions after the fix: `--tokens`/
`--ast` 102/102, full parity 50/50, binary behavior 8/8,
ASan/UBSan clean; self-emission: gen3 = gen2 byte-for-byte, with the `.c` from kraftc —
only two documented classes (28 lines).

## Self-hosting (xkraft, step 8)

Procedure (repeatable, cc is the only dependency):

1. `./xkraft/xkraft xkraft/xkraft.kraft` → `xkraft/xkraft.c`
   (lex+parse+analyze+emit, ~80 s);
2. `cc -std=c11 -O2 -o xkraft xkraft/xkraft.c -lm` (~2 s);
3. the resulting binary is a full compiler: it emits `.c` itself,
   running cc is the shell's job (kraft-run/user).

Update (growth stage, steps 1–2): the procedure is outdated in two
places — emission takes ~0.8 s, not ~80 s (offset cache, step 1), and
xkraft's default mode runs cc itself (`xkraft: собран`, step 2),
so the manual step 2 remains only for the `--emit` flow; the real
cc time for the self-binary is ~9–10 s (see "Growth stage, step 2").
The evidence below is a snapshot from the time the stage was closed.

Evidence (the self-binary against the kraftc reference, a full run
of all suites from steps 2–7):

- `--tokens`/`--ast` — md5 with kraftc, including a self-run on
  `xkraft.kraft`;
- full error parity (stderr + rc) — 50/50;
- CLI matrix — 16/16;
- behavior of compiled binaries (stdout/stderr/rc) — 8/8;
- ASan/UBSan — clean;
- fixed point: gen3 = gen2 byte-for-byte — the self-binary
  reproduces its own `.c` byte-for-byte;
- `.c` from kraftc ↔ from xkraft — only the two documented classes
  of step 6 (28 lines), binaries identical.

The self-hosting stage is closed. Next is the growth stage (optimization
of the naive port, a deferred library for Raspberry/Arduino).

## Growth stage, step 1: string offset cache in krt

Problem: self-emission took ~80 s, time grew quadratically
(850 lines — 5 s, 1700 — 18 s, 3400 — 82 s). The `-O0` profile:
98–99% — `krt_sym_skip`: any `src[i]` access to a string
(the lexer does this on every character) scanned characters from
the start of the string.

The solution is an internal optimization of `src/krt_all.h`; observable
behavior does not change (strings are immutable):

- in `KStr` — a position cache `(c_idx, c_byte)`: "character `c_idx`
  starts at byte `c_byte`"; the cache moves only to character boundaries
  (an invariant);
- `krt_sym_off(i)`: forward — from the cache (the lexer's sequential pass
  is O(1) per character); backward — a step-by-step walk left from
  the cache over the set of boundaries `{0} ∪ не-байты-продолжения` (it
  exactly matches the forward-reachable `krt_sym_skip`), so that
  taking the token text `src[tstart..pos]` costs O(token length),
  not O(position);
- `krt_bytes_to_sym` starts from the cache; it moves the cache only if
  there is no NUL between the positions (walking forward from NUL is impossible);
- diagnostics under `KRT_DIAG` (counters of forward/backward passes)
  — without the flag it is not compiled into the code.

The entry point is the same for the reference and the port — the shared header
`krt_all.h`, so verification is differential, against the golden snapshot BEFORE
the patch:

- gold: all modes (`--tokens`/`--ast`/full) of both compilers,
  stdout/stderr/rc separately, `.c`, behavior of compiled
  binaries — 1783 files; after the patch `diff -r` is empty;
- parities: tokens/AST 92/92, analyzer 50/50, CLI 16/16,
  `.c`+behavior 9/9 (FAIL=0; BYTE=4, DIFF=5 — only
  the documented class of octals `\320…`/`\033`; the old entry
  "5/3 out of 8" is a different fixture set, unrelated to the patch);
- self-hosting: md5 of `--tokens`/`--ast` of the self-binary matches kraftc,
  fixed point gen3 = gen4, ASan/UBSan clean;
- timings: `--tokens` 82 → 0.55 s, full emission 84 → 0.79 s,
  p1700 18.3 → 0.27 s; modes are now lexer-bound
  (~0.55 s), parse+analyze+emit ~0.25 s.

## Growth stage, step 2: autonomous cc and the system bilingual

- xkraft's default mode is now 1:1 with kraftc: emission + standalone
  cc + `xkraft: собран <бинарник>`; `--emit` is "only .c"
  (`записан`); a cc failure → stderr `xkraft: cc exited with an error`,
  rc 1 (as in kraftc);
- the `system(команда)` bilingual — POSIX: `/bin/sh -c` (the internal
  `system()`); exit code 0..255, on a signal — 128+number, if it did not
  start → -1; shared by kraftc and xkraft: strings in
  `analyze.c`/`emit.c` (g_globals, g_builtins, g_bi) mirror the
  strings in `xkraft.kraft` (bl_builtins, globals-список, bl_bimap);
  in krt — `krt_system` + `<sys/wait.h>`;
- the decision "default = --emit (option A)" from the stage discussion —
  overridden: default mirrors kraftc, `--emit` remains
  the special "only .c" mode;
- suites were strengthened for autonomy: full mode compares stdout
  always (normalizing the prefix `kraftc:` → `xkraft:`), cparity
  invokes xkraft with `--emit` (otherwise its cc overwrites the
  kraftc binary — behavior comparison becomes empty), CLI — `default_msg` and
  `default_full`;
- verification: tokens/AST 36/36, full mode 18/18, CLI 17/17,
  `.c`+behavior 10/10 (FAIL=0; BYTE=6, DIFF=4 — only
  the documented class of octals `\320…`), ASan clean;
  self-emission `./xkraft/xkraft xkraft/xkraft.kraft` →
  `xkraft: собран xkraft/xkraft`, fixed point (md5
  of `.c` unchanged), md5 `--tokens` = kraftc (`7eb621fc…`);
- note: a machine reboot wiped `/tmp/opencode` —
  the test infrastructure (fixtures/scripts) was recreated from scratch,
  with a different composition from the records of steps 5–8 (18 fixtures instead
  of 46/50; comparing "before/after" against those steps' records is incorrect);
- cc timings: `cc -O2` on generated C (314KB, 5036 lines)
  ~9–10 s, on kraftc sources (6 files) 1.7 s, governor
  powersave; the step 8 entry "~2 s" is inaccurate — a property
  of the generated code (heavy krt inlines), it does not affect correctness;
  xkraft self-emission ~10.5 s (0.5 emission + ~10 cc).

## Growth stage, step 3: the runtime as a separate krt.o object

Problem: every `.c` included the whole runtime (a ~1250-line header
with heavy inlines) — cc rebuilt the runtime for every program;
self-emission took ~10.5 s, of which ~10 was cc (see step 2: krt inlines are
the cause, not the machine).

Solution: krt is split into an interface and an implementation:

- `src/krt_all.h` — interface only: types, macros, prototypes;
  the generated `.c` includes it as before — the `.c` text did not
  change;
- `src/krt.c` → `src/krt.o` — function bodies; built once
  (`make`) and linked into all compiled programs;
- the cc command: `cc -std=c11 -O2 -o <bin> <bin>.c <krt.o> -lm`;
  the object path is baked into kraftc (`-DKFT_KRT_OBJ`, Makefile) and into
  xkraft.kraft (`krop`), kraft-run takes `src/krt.o` next to itself;
- `src/krt.c` builds with `-Wall -Wextra` — clean.

Transition step (one time): the old xkraft emits a new `.c`,
it is linked manually with krt.o — afterward self-emission is normal.

Evidence: the before/after golden snapshot — `diff -r` is empty across all
modes of kraftc and xkraft (stdout/stderr/rc separately, `.c`, behavior
of compiled binaries); parities: tokens/AST 36/36, full
18/18, CLI 17/17, `.c`+behavior 10/10 (BYTE=6, DIFF=4 — only the
octal class), ASan clean; self-emission — a fixed point.

Timings: self-emission 10.5 → 7.5 s (cc 9.9 → 5.5 s); the remaining
~5.5 s is gcc on the generated code itself (5036 lines of expressions),
the runtime is no longer part of it; `make` (krt.o + kraftc) — 2.5 s;
linking krt.o with a user program does not slow down startup.

## Growth stage, step 4: a parity audit across the whole language

Task: to check that the port covers the whole kraftc language, not only
the features that made it into the earlier suites (18 fixtures are a subset of the language).

Method: a fixture for every keyword/bilingual/method from README —
35 files (`a_` — positive, `e_` — negative), a full-mode
run (stderr/rc/stdout), tokens/AST and binary behavior.

Result: **no holes**. Merged into the main set (53 fixtures):
full parity 53/53, tokens/AST 106/106, binary behavior
26/26 (DIFF=9 — only the octal class), CLI 17/17. Checked in
particular: interpolation forms (`$x`, `$(выражение)`, `$f(...)`,
`\$`, escaping), `for i 5..9..2` ranges without `in`, comparison
chains, `# stdin:`, variable visibility after blocks, all
string/list/dict methods, all slice forms, runtime errors
(division by zero, slice step 0, out of bounds).

The negatives confirmed the full "outside v0" list (the kraftc parser, the
`nv0_words` table, replies `v0 feature: <слово> (growth stage)`): models
(`model`, `method`, `construct`, `self`, `init`), error handling
(`try`, `trigger`, `finally`, `panic`), `glob`, `froz`, files
(`import_file`, `from_file`, `import_lib`, `from_lib`),
`assert`/`expect`, `map`/`filter`/`reduce`. Error categories fired
as documented: CONST, SCOPE, TYPE, SYNTAX (the context of
`break`/`return`), ARGCOUNT, CONCATENATE_NOT_SUPPORT, Latin letters in
a function name, the hint about CapWords=model. Along the way the
syntax was clarified: function parameters must be typed, `|` is only
inside template quotes, `double` is a reserved C name.

Documentation conclusions: the README "Under development" section was incomplete (it listed
only `try`/`panic` and `map`/`filter`/`reduce`) — it has been supplemented with the full
list of nv0 words. The kraftc ↔ xkraft port covers all of v0.

## Growth stage, step 5: cc optimization level (-O2 → -O1)

The step's task was "optimization of the naive port" (speeding up cc on
the generated code). Measurements showed that the emitter structure is irrelevant,
and the step came down to choosing an optimization level.

Experiments (synthetic calls to `krt_*` and a real `xkraft.c`):

- emitter nesting depth: nested 9.4 s vs flat 8.7 s — ~8%;
- splitting giant functions into small ones: 8.8 s — 0%;
- optimization level: -O0 1.5 s, **-O1 3.4 s**, -Os 6.0 s, -O2
  6.3 s, -O3 7.1 s;
- binary speed: a loop of 30 million `krt_add` calls — 0.110 s both at -O1
  and at -O2: the generated code is glue for `krt_*` calls, gcc optimizes
  it in vain, all the work is in `krt.o` (built with -O2, the user's flag
  does not touch it).

Change: the cc command -O2 → -O1 in three places — kraftc's cc command,
xkraft.kraft's default branch, kraft-run; `Makefile` is untouched, it
builds hand-written C (krt.c, kraftc) and stays at -O2.
The emitted `.c` does not change by a single byte (the flag is not part of it).

Result: self-emission 7.5 → 4.6 s (cc ~3.4 s instead of ~5.5 s), kraftc
compiles xkraft.kraft in ~3.1 s.

Verification: the gold snapshot is empty (all modes + `.c` + behavior), tokens
kc == xk (md5), fixed point (passes 2 and 3 give identical `.c` and
binaries), the battery unchanged (106/106, 53/53, BYTE=17 DIFF=9
beh_ok=26, CLI 17/17), ASan clean on all 53 fixtures, kraft-run smoke test.

The question of "optimization of the naive port" is closed for good: aligning
the emitter would give ~0.5 s against 3 s, and a synchronized edit of two emitters
(emit.c + xkraft.kraft) does not pay off — the data are recorded here.

## Growth stage, step 6: make check — tests in the repository

The tests lived in `/tmp/opencode` and were lost twice when `/tmp` was
wiped (including the whole 53-fixture battery and the suite scripts).
The rule "tests only in /tmp" was revoked: the battery moved into the repo.

Composition:

- `tests/fixtures/` — 54 fixtures: 35 audit fixtures from step 4 (`a_*`
  positive, `e_*` negative), a recreated core of the old battery
  by purpose (templates, collections, functions, loops, slices, multibyte,
  the `system` bilingual — 4 cases, 5 error categories) and `t_args`
  (command-line arguments — needed by step 7);
- `tests/parity.sh` — `--tokens`/`--ast`, byte-for-byte (108 pairs);
- `tests/an_parity.sh` — full mode: stdout/stderr/rc, normalizing
  only the names `kraftc:`/`xkraft:` → `COMP:` (54);
- `tests/cparity.sh` — the `.c` class + binary behavior; DIFF —
  only known classes (octals `\NNN` vs raw UTF-8, %.17g),
  otherwise NEWCLASS → failure;
- `tests/cli_parity.sh` — 17 CLI cases (usage, flags, errors, modes).

The scripts run from repo paths (`dirname $0`/..), artifacts go to mktemp,
`XK`/`KC` are overridable. `make check` runs all four and fails
on any FAIL. Non-ASCII normalization in cparity requires `LC_ALL=C`
(under UTF-8 sed counts characters, not bytes — the octal count did not match).

Verification: `make check` is green — 108/108, 54/54, BYTE=21 DIFF=9
NEW=0 beh_fail=0, CLI 17/17; after a run there are no extra files in the repo.

## Growth stage, step 7: run mode in both compilers

`kraftc run file.kraft [args...]` and `xkraft run file.kraft [args...]` —
compile and immediately run the program. Previously only
`kraft-run` could do this, and via kraftc; the self-contained xkraft had no way
to run a file.

Semantics (one-to-one in both compilers):

- `run` is recognized only as the first argument; the other modes are
  untouched. A file named `run` is now unreachable directly (a keyword)
  — worked around with a path like `./run`;
- read/lexer/parser/analyzer errors — as in default (stderr, rc 1);
  running without a file — usage, rc 2;
- emission goes to a temporary directory `/tmp/kraft-run-<число>` (kraftc —
  wall seconds `time()`, xkraft — `time_ms()`; the path is normalized in
  the suite), nothing appears next to the source;
- launch — a single `system()`; arguments are quoted with the POSIX idiom
  (`'` → `'\''`, the same in C and in kraft);
- rc — the system bilingual: 0..255 / 128+signal number / 1 (did not start);
  in kraftc this is wait-status parsing as in `krt_system` — libc `system`
  returns the status as a whole (256 for rc=1 was truncated to 0, caught
  by the test on `e_divzero`/`t_exit`);
- artifacts are removed by the same `rm -rf ... 2>/dev/null` command on
  all exit paths; there are no tmp leaks (the suite checks before/after).

New language tools used: `part("/")` — basename,
`replace` with quoting, an empty `join("")` — command assembly,
`time_ms()` — the tmp directory name.

Verification: `tests/run_parity.sh` — 9 byte-for-byte cases (program
output, arguments, rc via `exit(7)`, runtime and compile errors,
embedded stdin, usage, no file) + source directory cleanliness and
no tmp leaks. `make check`: 110/110, 55/55, BYTE=21 DIFF=10
NEW=0 beh_fail=0, CLI 17/17, run 9/9; fixed point of self-emission
(.c and binaries), token md5 kc == xk, ASan clean (55 fixtures and
run mode), `kraft-run` is untouched and works.

## Growth stage, step 8: xkraft at the project root

- The `xkraft/` directory was removed: `xkraft.kraft` (the source) is at the
  repository root, the `xkraft` binary and generated `xkraft.c` are also
  at the root (both in `.gitignore`, the paths in `.gitignore` were updated
  from `/xkraft/xkraft` to `/xkraft`).
- Self-emission now runs from the root: `./xkraft xkraft.kraft` →
  `xkraft: собран xkraft`; fixed point (passes give identical
  `.c` and binary), token md5 kc == xk — `789b93d0...` (unchanged:
  only the path to the source was edited, not the code).
- Suites: XK defaults to `$REPO/xkraft`; `make check` is green
  with unchanged numbers: 110/110, 55/55, BYTE=21 DIFF=10 NEW=0,
  CLI 17/17, run 9/9.
- `exam.c`/`exam` were removed from the root and remain in `.gitignore`;
  nothing needs to be created for the sandbox — `run` mode
  (`./kraftc run exam.kraft`) writes no artifacts next to the source.
  By spec, default mode puts `.c` and the binary next to the file —
  the contract has not changed.

## Growth stage, step 9: default is run, compilation is `-c`

The user's decision: remove the mandatory word `run` — "just
`./xkraft exam.kraft`" runs the program and leaves no garbage;
compilation into files next to the source (the former default) becomes
explicit — the `-c` flag (as in cc). Both compilers change identically —
parity is preserved.

- CLI (the same for kraftc and xkraft): `COMP [run] file.kraft [args...]`
  — launch in a temporary directory, artifacts are deleted; `COMP -c
  file.kraft` — `.c` + binary next to the source (the former default);
  `--emit`/`--tokens`/`--ast` — unchanged. Flags are recognized
  only as the first word: everything after the file is program arguments (as
  in python). Usage: `COMP: usage: COMP [-c|--tokens|--ast|--emit] file.kraft [args...]`.
- Internally: `run_mode` gained a file index (1 — a plain invocation,
  2 — the `run` alias); dispatch on the first token in main/xmain; `-c` is
  the want_compile variable, the "tail" of compilation is untouched. `kraft-run`
  is unaffected — it calls `--emit` as the first word.
- Suites: an_parity/cparity — invoked with `-c`; cli_parity — `two_files`
  now via `-c`, plus the `usage_c_only` and `plain_missing` cases
  (19 cases); run_parity — a mode parameter (run|plain) plus 4 cases
  of a plain invocation (13).
- Verification: `make check` — 110/110, 55/55, BYTE=21 DIFF=10 NEW=0
  beh_ok=31, CLI 19/19, run 13/13; self-emission `./xkraft -c xkraft.kraft`
  — fixed point (.c and binary); token md5 kc == xk — `e408f044...`
  (changed — the source has a new CLI); ASan clean (55 fixtures + run).
