import { channel } from "./socket"
import "phoenix_html"
import * as Fmodel from "./fmodel.js"

Fmodel.start({ channel })
