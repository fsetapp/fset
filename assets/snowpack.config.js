process.env.NODE_ENV ||= "development"

/** @type {import("snowpack").SnowpackUserConfig } */
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
    bundle: true,
    minify: true,
    target: 'es2018'
  },
  plugins: [
    ["@snowpack/plugin-postcss"]
  ],
}
