import "phoenix_html"
import "@github/tab-container-element"
import "@github/details-menu-element"
import Search from "./search.js"
import autosize from "autosize"

import { channel } from "./socket"
import * as Fmodel from "./fmodel.js"

if (channel) Fmodel.start({ channel })

Search.start()

autosize(document.querySelectorAll("input, textarea"))
