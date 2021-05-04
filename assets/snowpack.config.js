process.env.NODE_ENV = process.env.NODE_ENV || "development"

module.exports = {
  mount: {
    "js": { url: "/js" },
    "css": { url: "/css" },
    "static": { url: "/", static: true, resolve: false }
  },
  buildOptions: {
    out: "../priv/static/"
  },
  optimize: {
    entrypoints: ["js/app.js"],
    bundle: true,
    minify: true,
    target: 'es2018'
  },
  plugins: [
    ["@snowpack/plugin-postcss"]
  ],
}
