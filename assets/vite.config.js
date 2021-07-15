export default {
  publicDir: "./static",
  build: {
    target: "es2018",
    minify: true,
    outDir: "../priv/static",
    emptyOutDir: true,
    rollupOptions: {
      input: ["js/app.js", "css/app.css", "js/paddle.js", "js/docs_page.js"],
      output: {
        entryFileNames: "js/[name].js",
        chunkFileNames: "js/[name].js",
        assetFileNames: "[ext]/[name][extname]"
      }
    },
    assetsInlineLimit: 0
  }
}
