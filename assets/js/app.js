import "phoenix_html"
import "@github/tab-container-element"

import { channel } from "./socket"
import * as Fmodel from "./fmodel.js"

if (channel) Fmodel.start({ channel })
