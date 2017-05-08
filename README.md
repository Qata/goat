# G.O.A.T. ![Travis](https://travis-ci.org/thebritican/goat.svg?branch=master)
### Graphics Ornamentation and Annotation Tool
### a.k.a. Greatest Of All Time

## Demo
![goat-demo](https://cloud.githubusercontent.com/assets/3099999/25797188/0afd1206-3391-11e7-9a6f-06e82f07affe.gif)

## Motivation

This will soon be a [Zendesk Editor App](https://www.zendesk.com/apps/directory/#Compose_&_Edit)

## Credits

👏 Huge thanks to [Jian Wei Liau](https://twitter.com/madebyjw) for some beautiful icons and logo! 👏

Epic 🐐-ing to [Alan Hogan](https://github.com/alanhogan) for the acronym behind the 🐐, some bugfixes, and more icons!

## Development


#### Dead simple setup

Get yourself the [Elm programming language](http://elm-lang.org/):

On node 6+: `npm install -g elm && npm install`

Then you can just do `elm-make src/Main.elm --output=elm.js --debug` and open `index.html`.

#### Nicer workflow

Use `elm-live` (`npm install -g elm-live`)

```
elm-live src/Main.elm --output=elm.js --open --debug
```

This will open a browser tab with CSS hot reloading and page refreshing on Elm code changes.


#### Testing

Setup for first time Elm testers:

`npm i -g elm-test`

Use `npm test` to run the `elm-test` unit, fuzz, and view tests.

## Contributing

This project is welcome to any PRs, first time Elm programmer or not!

If it's a change requiring a decent amount of work, let's chat first!

DM me on [The Elm Language Slack](https://elmlang.herokuapp.com) (**@greg.ziegan**)

Or, make an issue!
