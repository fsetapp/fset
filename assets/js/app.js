import "phoenix_html"
import "@github/tab-container-element"
import "@github/details-menu-element"
import "@github/include-fragment-element"
import Search from "./search.js"

import { channel } from "./socket"
import * as Repo from "./repo.js"

if (channel) Repo.init("project-store", channel)

Search.start()

document.addEventListener("click", e => {
  for (let d of document.querySelectorAll("details[open]"))
    if (!d.contains(e.target))
      d.removeAttribute("open")
})
