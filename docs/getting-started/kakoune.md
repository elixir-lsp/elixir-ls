# Kakoune

## Setup

Install the [kak-lsp](https://github.com/kak-lsp/kak-lsp) client for the [Kakoune](http://kakoune.org) editor.

## Limitations

### Encoding

kak-lsp works only with UTF-8 documents.

### `Position.character` interpretation

Currently, kak-lsp doesn't conform to the spec regarding the interpretation of `Position.character`.
LSP spec says that

____
A position inside a document (see Position definition below) is expressed as a zero-based line and
character offset. The offsets are based on a UTF-16 string representation. So for a string of the
form `a𐐀b` the character offset of the character `a` is 0, the character offset of `𐐀` is
1 and the character offset of `b` is 3 since `𐐀` is represented using two code units in UTF-16.
____

However, kak-lsp treats `Position.character` as an offset in UTF-8 code points by default.
Fortunately, it appears to produce the same result within the Basic Multilingual Plane (BMP) which
includes a lot of characters.

Unfortunately, many language servers violate the spec as well, and in an inconsistent manner. Please
refer https://github.com/Microsoft/language-server-protocol/issues/376 for more information. There
are two main types of violations we met in the wild:

1) Using UTF-8 code points, just like kak-lsp does. Those should work well with kak-lsp for
characters outside BMP out of the box.

2) Using UTF-8 code units (bytes), just like Kakoune does. Those are supported by kak-lsp but
require adding `offset_encoding = "utf-8"` to the language server configuration in `kak-lsp.toml`.

