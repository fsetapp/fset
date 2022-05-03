const replaceWith = ({ url, currentFile }) =>
  currentFile && history.replaceState(null, "", `${url.path}/m/${encodeURIComponent(currentFile.key)}${location.hash}`)

export default { replaceWith }
