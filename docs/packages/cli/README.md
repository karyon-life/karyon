# `@treeseed/cli`

Operator-facing Treeseed CLI package.

This package owns the published `treeseed` binary and delegates command execution into the Treeseed platform runtime. It is intended to be installed alongside `@treeseed/core`.

Typical tenant dependency set:

```json
{
  "dependencies": {
    "@treeseed/cli": "^0.0.1",
    "@treeseed/core": "^0.0.1"
  }
}
```
