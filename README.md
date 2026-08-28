# Stargrid-systems Tap

## AVR toolchain

This tap provides a GNU AVR toolchain that builds and runs on both Linux and
macOS.

- `avr-binutils` (Binutils 2.46.0)
- `avr-gcc` (GCC 15.3.0, bundles AVR-Libc 2.3.2)
- `simavr` (1.8)

```console
$ brew tap stargrid-systems/tap
$ brew install avr-gcc
```

## How do I install these formulae?

`brew install stargrid-systems/tap/<formula>`

Or `brew tap stargrid-systems/tap` and then `brew install <formula>`.

Or, in a `brew bundle` `Brewfile`:

```ruby
tap "stargrid-systems/tap"
brew "<formula>"
```

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).
