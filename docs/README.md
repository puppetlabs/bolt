# Bolt Hands-On Lab

## Development

### Setup

```
bundle install --path vendor/bundle
```

### Building the site

To start a local development server
```
jekyll server
```

To just build the site:
```
jekyll build
```

### Publishing

To publish the site, create a PR against the master branch of Bolt. Once merged, your changes will be live.

### Modifying CSS

You have to transpile the Sass (`.scss`) files to CSS to see them rendered in a local dev server.

```
sass input_file.scss output_file.css
```

To watch the file for changes instead of manually building every time
```
sass --watch input_file.scss:output_file.css
```