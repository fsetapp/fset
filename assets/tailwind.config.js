module.exports = {
  purge: {
    enabled: true,
    content: [
      "../lib/fset_web/templates/**/*.{leex,eex}",
      "../lib/fset_web/views/*.ex",
      "./js/**/*.js"
    ],
    options: {
      safelist: []
    }
  }
}
