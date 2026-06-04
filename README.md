# Fset

This is a rewritten version of LiveView as view layer https://github.com/50kudos/_fset/tree/master/lib/fset_web/live. We now use a bare Phoenix Channel + Javascript of achieve lowest latency interaction.

## Development

```bash
# install mise
# it will work with the .tool-versions


# tesing fbox package without publishing the package to registry yet.
# cd into fbox project
npm install
# build and copy unpublished npm package to fset project
./do_build.sh

# fset project
brew install pnpm

cd assests
pnpm --dir assests install --link-workspace-packages
cd ..

# run app
mix phx.server
```


## Production

```bash
# manual migrate db
kamal app exec --primary -i "/app/bin/migrate"
# troublesheeting
ssh root@<ip>
docker logs fset-db
docker exec -it fset-db psql -U fset -d fset_production
```
