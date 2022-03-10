// @ts-check

import { storiesOf } from "@storybook/react"
import * as React from "react"

import ElmComponent from "react-elm-components"

/**
 * @typedef {{[key: string]: { subscribe: () => void, send: () => void}}} Ports
 */

/**
Load a `*.elm` file that uses ElmStorybook, adding the stories to react-storybook

@param {string} name The name of this collection of stories. eg. `"Text (Elm)"`
@param {NodeModule} module Use the value `module`. This is required for Hot Module Reloading. eg. `module`
@param {any} elmApp The Elm file you wish to import. eg. `require('./TextStores.elm')`
@param {string[]}storyNames An array of stories to add to this collection. These names must match those defined in the Elm Storybook. eg. `['h1', 'h2', 'h3']`
@param {(ports: Ports) => void} ports The javascript functions an Elm program may send and subscribe to via ports

```js
import { loadElmStories } from "@cultureamp/elm-storybook"

loadElmStories("Text (Elm)", module, require("./TextStories.elm"), [
  "h1",
  "h2",
  "h3"
])
```
*/
export const loadElmStories = (
  name,
  module,
  elmApp,
  storyNames,
  ports,
) => {
  const stories = storiesOf(name, module)
  for (const storyName of storyNames) {
    stories.add(storyName, () => (
      React.createElement(ElmComponent, {
        src: elmApp,
        flags: storyName,
        ports
      })
    ))
  }
}
