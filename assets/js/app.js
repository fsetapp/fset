import "phoenix_html"
import "@github/tab-container-element"
import "@github/time-elements"
import "@github/details-menu-element"

import { channel } from "./socket"
import * as Fmodel from "./fmodel.js"

if (channel) Fmodel.start({ channel })
