# Fset

## Development
Internal frontend stuff is installed via yarn and normally imported from node_modules.
For example:
```js
  import * as Model from "@fsetapp/fset/pkgs/model.js"
```
However, we don't have to develop on published package. We use `yarn link @fsetapp/fset` to link `node_modules/@fsetapp/fset` to `js/internal` which is an unpublished in-progress local code from different git repo (`cp -r ./lib/pkgs/fset ~/dev/product/fset/assets/js/internal/`)
