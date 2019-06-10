# Bolt Hands-On Lab

## Development

### Setup

```
bundle install --path vendor/bundle
```

### Building the site

To start a local development server
```
bundle exec jekyll server --baseurl /bolt
```

Go to `http://localhost:4000/bolt/` to see the site running. Changes will be picked up automatically without restarting the server.

To just build the site:
```
bundle exec jekyll build
```

### Publishing

To publish the site, create a PR against the master branch of Bolt. Once merged, your changes will be live.
