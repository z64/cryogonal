# cryogonal

Composable Discord API library and toolkit for Crystal.

This library is a continuation of [discordcr](https://github.com/meew0/discordcr)
written by [meew0](https://github.com/meew0), myself, and [RX14](https://github.com/RX14).
For more details on the differences and motivation between the two, see the
comparison section below.

## References

- [Library documentation]() (Coming soon - you can build locally for now.)
- [Library support server](https://discord.gg/NuAvs7j)
- [Crystal language](https://crystal-lang.org/)
- [Discord API documentation](https://discordapp.com/developers/docs/intro)

## Introduction

Cryogonal aims to be a library that implements a bare "toolkit" that abstracts
Discord's API. The library is composed of small components that have as little
state as possible, if any at all, laid out in a manner that directly translates
as close to Discord's official API documentation as closely as possible. In
other words, Discord's documentation should also serve as documentation for
this library. A benefit of this approach is that the library's stability will
closely follow that of Discord's.

Many of the "lower level" components require experienced knowledge of Discord's
API to operate to their fullest potential. That said, we aim to leverage
features of the Crystal language as well as documentation of best practices and
common pitfalls to help users write safe and efficient bots regardless.

The library will also provide higher level types that compose these components
and expose an API that allows for easy designing of highly efficient bots and
applications by default. Users that need behaviors optimized for their use
cases can use the public internals to get their job done, at the exchange of
taking full responsibility of runtime performance and stability.

## Library Status

This isn't usable yet, unless you're looking to help with development. Please
contact me first if you're interested in doing so.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     cryogonal:
       github: z64/cryogonal
   ```

2. Run `shards install`

## Usage

```crystal
require "cryogonal"
```

## Comparison to discordcr

TODO

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/z64/cryogonal/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Zac Nowicki](https://github.com/z64) - creator and maintainer
- [meew0](https://github.com/meew0) - discordcr author
- [RX14](https://github.com/rx14) - discordcr contributor
- [GeopJr](https://github.com/GeopJr) - library name inspiration
