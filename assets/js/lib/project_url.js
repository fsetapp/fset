const replaceWith = ({ url, currentFileKey }) =>
  history.replaceState(null, "", `${url.path}/m/${encodeURIComponent(currentFileKey)}${location.hash}`)

export default { replaceWith }
