module View.ObjectView exposing (noEvents, viewDesk, viewLabel)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode
import Util.HtmlUtil exposing (..)
import View.Styles as S
import View.Icons as Icons
import Model.Scale as Scale exposing (Scale)
import String


type alias Id = String


type alias EventOptions msg =
  { onMouseDown : Maybe ((Int, Int) -> msg)
  , onMouseUp : Maybe msg
  , onStartEditingName : Maybe msg
  , onContextMenu : Maybe msg
  , onStartResize : Maybe msg
  }


noEvents : EventOptions msg
noEvents =
  { onMouseDown = Nothing
  , onMouseUp = Nothing
  , onStartEditingName = Nothing
  , onContextMenu = Nothing
  , onStartResize = Nothing
  }


viewDesk : EventOptions msg -> Bool -> (Int, Int, Int, Int) -> String -> String -> Float -> Bool -> Bool -> Scale -> Bool -> Bool -> Html msg
viewDesk eventOptions showPersonMatch rect color name fontSize selected alpha scale disableTransition personMatched =
  let
    personMatchIcon =
      if showPersonMatch then
        personMatchingView scale name personMatched
      else
        text ""

    screenRect =
      Scale.imageToScreenForRect scale rect

    styles =
      [ style (S.deskObject screenRect color selected alpha disableTransition) ]

    nameView =
      objectLabelView "" fontSize scale disableTransition screenRect name
  in
    viewInternal selected eventOptions styles nameView personMatchIcon


viewLabel : EventOptions msg -> (Int, Int, Int, Int) -> String -> String -> String -> Float -> Bool -> Bool -> Bool -> Bool -> Scale -> Bool -> Html msg
viewLabel eventOptions rect backgroundColor fontColor name fontSize isEllipse selected isGhost rectVisible scale disableTransition =
  let
    screenRect =
      Scale.imageToScreenForRect scale rect

    styles =
      [ style (S.labelObject isEllipse screenRect backgroundColor fontColor selected isGhost rectVisible disableTransition) ]

    nameView =
      objectLabelView fontColor fontSize scale disableTransition screenRect name
  in
    viewInternal selected eventOptions styles nameView (text "")


viewInternal : Bool -> EventOptions msg -> List (Html.Attribute msg) -> Html msg -> Html msg -> Html msg
viewInternal selected eventOptions styles nameView personMatchIcon =
  let
    eventHandlers =
      ( case eventOptions.onContextMenu of
          Just msg ->
            [ onWithOptions "contextmenu" { stopPropagation = True, preventDefault = True } (Decode.succeed msg)
            ]
          Nothing -> []
      ) ++
      ( case eventOptions.onMouseDown of
          Just msg ->
            [ onWithOptions "mousedown" { stopPropagation = True, preventDefault = False } (Decode.map msg decodeClientXY)
            ]
          Nothing -> []
      ) ++
      ( case eventOptions.onMouseUp of
          Just msg ->
            [ onWithOptions "mouseup" { stopPropagation = True, preventDefault = False } (Decode.succeed msg)
            ]
          Nothing -> []
      ) ++
      ( case eventOptions.onStartEditingName of
          Just msg -> [ onDoubleClick msg ]
          Nothing -> []
      )
  in
    div
      ( styles ++ eventHandlers )
      [ nameView
      , personMatchIcon
      , resizeGripView selected eventOptions.onStartResize
      ]


resizeGripView : Bool -> Maybe msg -> Html msg
resizeGripView selected onStartResize =
  case onStartResize of
    Just msg ->
      div
        [ style (S.deskResizeGrip selected)
        , onWithOptions "mousedown" { stopPropagation = True, preventDefault = False } (Decode.succeed msg)
        ]
        []
    Nothing ->
      text ""


personMatchingView : Scale -> String -> Bool -> Html msg
personMatchingView scale name personMatched =
  let
    ratio =
      Scale.imageToScreenRatio scale
  in
    if name /= "" && personMatched then
      div [ style (S.personMatched ratio) ] [ Icons.personMatched ratio ]
    else if name /= "" && not personMatched then
      div [ style (S.personNotMatched ratio) ] [ Icons.personNotMatched ratio ]
    else
      text ""


objectLabelView : String -> Float -> Scale -> Bool -> (Int, Int, Int, Int) -> String -> Html msg
objectLabelView color fontSize scale disableTransition screenRect name =
  let
    (_, _, _, height) =
      screenRect

    trimed =
      String.trim name

    ratio =
      Scale.imageToScreenRatio scale

    styles =
      S.nameLabel
        color
        ratio
        fontSize
        disableTransition  --TODO
  in
    div
      [ style styles ]
      [ text trimed ]
