module.exports = {
  mode: "jit",
  darkMode: "class",
  content: [
    "../lib/fset_web/templates/**/*.{leex,eex}",
    "../lib/fset_web/views/*.ex",
    "./js/**/*.js"
  ],
  plugins: [
    require("@tailwindcss/typography")
  ],
}
