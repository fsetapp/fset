module.exports = {
  mode: "jit",
  darkMode: "class",
  purge: [
    "../lib/fset_web/templates/**/*.{leex,eex}",
    "../lib/fset_web/views/*.ex",
    "./js/**/*.js"
  ],
  plugins: [
    require("@tailwindcss/typography")
  ],
}
