# Kraft Philosophy

> Russian original: [philosophy.md](philosophy.md). The Russian version is authoritative.

Kraft is a small language in which three things matter: clear text, clear
errors, and the ability to write the compiler itself in the language.

## Principles

1. **An error is part of the interface.** The message must name the category,
   file, and line and show a caret. The format is `expected X, found Y`, without
   internal debugging words.
2. **A smaller core, more useful libraries.** New behavior is first sought in a
   Kraft library, not in a new keyword. The standard library is limited to:
   `std/fos` and `std/cli`.
3. **One numeric type.** `flint` covers integers and fractional numbers; there
   is no separate `int`/`float`. The `..` range is a value, not a separate
   declaration.
4. **Code reads like text.** Indentation instead of curly braces, `{}` instead
   of string concatenation, `show()` instead of printf templates. Its own words
   are `trigger`, `..`, `in`.
5. **One binary.** `.kraft` → Lua → LuaJIT. No C toolchain and no build step for
   the user.
6. **One language for everything.** The core, examples, stdlib, and `xkraft`
   itself are written in Kraft. Frozen v0.1 lives only in `dev/` as a reference.

## Self-hosting as a Criterion

`xkraft` must build itself with frozen v0.1 and at the same time produce
byte-for-byte the same Lua as the direct compiler. This is not a trick for its
own sake: if a language cannot express its own compiler, it is too small or too
awkward for real programs.

That is why `dev/xkraft.kraft` is limited to the v0.1 subset: no new constructs,
`froz`, `panic`, `try`, or models. New features are tested on a separate
compiler, but compatibility remains the reference.

## What We Deliberately Do Not Do

- `_` / `__` as privacy: the prefix is only a convention for the reader, the
  name remains ordinary and importable; name choice is up to the importing file.
- `clamp`, `lerp`, `is_even`: niche functions do not expand the core. `std/math`
  appeared in `0.9.1` (D120), but only with `pow` and `random` — as a library,
  not as new keywords.
- Inheritance, polymorphism, and encapsulation as language-level OOP: patterns
  live in std. `class` is not introduced — its role is filled by `model`;
  properties and operator overloading remain separate future decisions.
- `read()`, `ask()`, `echo`, and `$` syntax alongside `show`, `show_err`, `input`.

The goal is not "more features", but a language you can hold in your head and
that can prove itself.
