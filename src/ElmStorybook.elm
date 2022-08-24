module ElmStorybook exposing
    ( storybook
    , storyOf
    , statelessStoryOf
    , StatelessMsg
    , StoryConfig
    )

{-| A module to allow writing Elm Html views as "stories" that can be viewed in React Storybook.

Example usage:

    import ElmStorybook exposing (statelessStoryOf, storybook)
    import Html exposing (text)
    import Text.Text as Text exposing (h1, view)

    main =
        storybook
            [ statelessStoryOf "h1" <|
                Text.view
                    Text.h1
                    [ Html.text "This is a h1" ]
            , statelessStoryOf "h2" <|
                Text.view
                    Text.h2
                    [ Html.text "This is a h2" ]
            , statelessStoryOf "h3" <|
                Text.view
                    Text.h3
                    [ Html.text "This is a h3" ]
            ]

@docs storybook
@docs storyOf
@docs statelessStoryOf
@docs StatelessMsg
@docs StoryConfig

-}

import Browser
import Dict exposing (Dict, get)
import Html exposing (..)
import Html.Attributes exposing (style)
import Platform.Cmd


{-| Create a program capable of displaying a story from a list

We use a String app init flag to determine which of the stories to render.
We never change which story is rendered for the lifecycle of the app.
Storybook will simply spawn a new Elm app when the flags (and hence current story) change.

You can use `storyOf` and `statelessStoryOf` to construct your stories.

Please note the types of your stories must match within a given storybook.
They must all either be stateless, or all be stateful with the same `customModel` and `customMsg` types.

-}
storybook : List (Story customModel customMsg) -> Platform.Program String (Model customModel customMsg) customMsg
storybook stories =
    let
        storybookInit : String -> ( Model customModel customMsg, Cmd customMsg )
        storybookInit storyName =
            let
                storiesAsTuples =
                    List.map (\story -> ( story.name, story )) stories

                storyDict =
                    Dict.fromList storiesAsTuples

                currentStory =
                    Dict.get storyName storyDict

                ( initCustomModel, initCommand ) =
                    case currentStory of
                        Just story ->
                            story.config.init |> Tuple.mapFirst Just

                        Nothing ->
                            ( Nothing, Cmd.none )
            in
            ( { currentStoryName = storyName
              , currentStory = currentStory
              , customModel = initCustomModel
              }
            , initCommand
            )

        storybookView : Model customModel customMsg -> Html customMsg
        storybookView model =
            case ( model.currentStory, model.customModel ) of
                ( Just currentStory, Just customModel ) ->
                    currentStory.view customModel

                ( _, _ ) ->
                    text ("Story " ++ model.currentStoryName ++ " not found")

        storybookUpdate : customMsg -> Model customModel customMsg -> ( Model customModel customMsg, Cmd customMsg )
        storybookUpdate msg model =
            let
                ( updatedCustomModel, commands ) =
                    case ( model.currentStory, model.customModel ) of
                        ( Just currentStory, Just customModel ) ->
                            let
                                ( updatedModel, updatedCommands ) =
                                    currentStory.config.update msg customModel
                            in
                            ( Just updatedModel, updatedCommands )

                        ( _, _ ) ->
                            ( model.customModel, Cmd.none )
            in
            ( { model | customModel = updatedCustomModel }, commands )

        storybookSubs : Model customModel customMsg -> Sub customMsg
        storybookSubs model =
            case ( model.currentStory, model.customModel ) of
                ( Just currentStory, Just customModel ) ->
                    currentStory.config.subscriptions customModel

                ( _, _ ) ->
                    Sub.none
    in
    Browser.element
        { init = storybookInit
        , view = storybookView
        , update = storybookUpdate
        , subscriptions = storybookSubs
        }


{-| The full model used to display the whole storybook.
This includes the currentStory, and the model used for the currentStory.
Both `currentStory` and `customModel` are None if a story with the given name is not found in the storybook.
This is for internal use only. Stories only have access to their own `customModel`.
-}
type alias Model customModel customMsg =
    { currentStoryName : String
    , currentStory : Maybe (Story customModel customMsg)
    , customModel : Maybe customModel
    }


{-| The definition of a particular story.
Use `storyOf` or `statelessStoryOf` to create a story.
-}
type alias Story customModel customMsg =
    { name : String
    , config : StoryConfig customModel customMsg
    , view : customModel -> Html customMsg
    }


{-| Config for stories that require state

For use with `storyOf`.

You can specify:

  - `init` - the initial model, and command (or Cmd.none if no command is required)
  - `update` - the update function for updating your model based on messages
  - `subscriptions` - the subscriptions (or Sub.none if no subscriptions are required)

-}
type alias StoryConfig customModel customMsg =
    { init : ( customModel, Cmd customMsg )
    , update : customMsg -> customModel -> ( customModel, Cmd customMsg )
    , subscriptions : customModel -> Sub customMsg
    }


{-| Create a complex story (that requires state changes)

Stateful stories have the ability to update their model in response to messages or subscriptions.
They can also issue commands.

    update : MyMsg -> MyModel -> (MyModel, Cmd MyMsg)
    update msg model =
        ...

    initModel : MyModel
    initModel =
        ...

    config =
        { update = update
        , init = ( initModel, Cmd.none )
        , subscriptions = \model -> Sub.none
        }

    storyOf "Single Select" config <|
        \model ->
            Html.map SelectMsg <|
                div [ style "width" "300px", style "margin-top" "12px" ]
                    [ Select.view
                        (Select.single (buildSelected model)
                            |> Select.state model.selectState
                            |> Select.menuItems (List.map buildMenuItems model.members)
                            |> Select.searchable False
                            |> Select.placeholder ( "Placeholder", Select.Bold )
                        )
                        (Select.selectIdentifier "Single Select")
                    ]

Please note any given storybook needs to have the same `customModel` and `customMsg` type for each story.
You can re-use the config object for each story, or change the init, update, and subscriptions for a particular story, as long as the `customModel` and `customMsg` types match.
(This same rule means you cannot use `storyOf` stateful stories, and `statelessStoryOf` stories in the same storybook).

-}
storyOf : String -> StoryConfig customModel customMsg -> (customModel -> Html customMsg) -> Story customModel customMsg
storyOf name config view =
    { name = name
    , config = config
    , view = view
    }


{-| Create a simple (stateless) story

Many components are simple view functions with no state.
This helper makes it easier to generate stories that don't have to worry about models, updates, subscriptions or commands.

    statelessStoryOf "h1" (Text.view Text.h1 [ Html.text "This is a h1" ])

or, using a pipe:

    statelessStoryOf "h1" <|
        Text.view
            Text.h1
            [ Html.text "This is a h1" ]

-}
statelessStoryOf : String -> Html customMsg -> Story StatelessModel customMsg
statelessStoryOf name view =
    let
        statelessInit : StatelessModel
        statelessInit =
            NoModel

        statelessUpdate : customMsg -> StatelessModel -> ( StatelessModel, Cmd customMsg )
        statelessUpdate msg model =
            ( model, Cmd.none )

        statelessSubscriptions : StatelessModel -> Sub customMsg
        statelessSubscriptions model =
            Sub.none

        statelessConfig =
            { init = ( statelessInit, Cmd.none )
            , update = statelessUpdate
            , subscriptions = statelessSubscriptions
            }
    in
    { name = name
    , config = statelessConfig
    , view = \_ -> view
    }


{-| A simple message type to use on stateless stories.
-}
type StatelessMsg
    = NoMsg


{-| A simple model type to use on stateless stories.
-}
type StatelessModel
    = NoModel
