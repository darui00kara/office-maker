module Component.FloorProperty exposing(..)

import Json.Decode as Decode
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy as Lazy

import Util.HtmlUtil exposing (..)

import View.Styles as Styles

import Model.User as User exposing (User)
import Model.Floor exposing (Floor)
import Model.I18n as I18n exposing (Language)

import Component.Dialog as Dialog exposing (Dialog)


type Msg
  = NoOp
  | InputFloorName String
  | InputFloorOrd String
  | InputFloorRealWidth String
  | InputFloorRealHeight String


type Event
  = OnNameChange String
  | OnOrdChange Int
  | OnRealSizeChange (Int, Int)


type alias FloorProperty =
  { nameInput : String
  , realWidthInput : String
  , realHeightInput : String
  , ordInput : String
  , deleteFloorDialog : Dialog
  }


init : String -> Int -> Int -> Int -> FloorProperty
init name realWidth realHeight ord =
  { nameInput = name
  , realWidthInput = toString realWidth
  , realHeightInput = toString realHeight
  , ordInput = toString ord
  , deleteFloorDialog = Dialog.init
  }


validName : String -> Bool
validName s =
  String.length s > 0


update : Msg -> FloorProperty -> (FloorProperty, Maybe Event)
update message model =
  case message of
    NoOp ->
      (model, Nothing)

    InputFloorName name ->
      let
        newModel =
          { model | nameInput = name }

        event =
          if validName name then Just (OnNameChange name) else Nothing
      in
        (newModel, event)

    InputFloorOrd ord ->
      let
        newModel = { model | ordInput = ord }
      in
        (newModel, ordEvent ord)

    InputFloorRealWidth width ->
      let
        newModel = { model | realWidthInput = width }
      in
        (newModel, sizeEvent newModel)

    InputFloorRealHeight height ->
      let
        newModel = { model | realHeightInput = height }
      in
        (newModel, sizeEvent newModel)


ordEvent : String -> Maybe Event
ordEvent ord =
  case String.toInt ord of
    Ok ord ->
      Just <| OnOrdChange ord

    Err s ->
      Nothing


sizeEvent : FloorProperty -> Maybe Event
sizeEvent newModel =
  case ( parsePositiveInt newModel.realWidthInput
       , parsePositiveInt newModel.realHeightInput
       ) of
    (Just width, Just height) ->
      Just <| OnRealSizeChange (width, height)

    _ ->
      Nothing


parsePositiveInt : String -> Maybe Int
parsePositiveInt s =
  case String.toInt s of
    Err s -> Nothing
    Ok i ->
      if i > 0 then Just i else Nothing


-- VIEW


floorNameInputView : Language -> User -> FloorProperty -> Html Msg
floorNameInputView lang user model =
  let
    floorNameLabel =
      label [ style Styles.floorNameLabel ] [ text (I18n.name lang) ]
  in
    div
      [ style Styles.floorNameInputContainer ]
      [ floorNameLabel
      , nameInput user model.nameInput
      ]


nameInput : User -> String -> Html Msg
nameInput user value =
  if User.isAdmin user then
    input
    ([ Html.Attributes.id "floor-name-input"
    , type_ "text"
    , style Styles.floorNameInput
    ] ++ (inputAttributes InputFloorName (always NoOp) value Nothing))
    []
  else
    div [ style Styles.floorNameText ] [ text value ]


floorOrdInputView : Language -> User -> FloorProperty -> Html Msg
floorOrdInputView lang user model =
  let
    floorOrdLabel = label [ style Styles.floorOrdLabel ] [ text (I18n.order lang) ]
  in
    div [ style Styles.floorOrdInputContainer ] [ floorOrdLabel, ordInput user model.ordInput ]


ordInput : User -> String -> Html Msg
ordInput user value =
  if User.isAdmin user then
    input
    ([ Html.Attributes.id "floor-ord-input"
    , type_ "text"
    , style Styles.floorOrdInput
    ] ++ (inputAttributes InputFloorOrd (always NoOp) value Nothing))
    []
  else
    div [ style Styles.floorOrdText ] [ text value ]


floorRealSizeInputView : Language -> User -> FloorProperty -> Html Msg
floorRealSizeInputView lang user model =
  let
    useReal = True -- TODO

    widthLabel = label [ style Styles.widthHeightLabel ] [ text (I18n.widthMeter lang) ]

    heightLabel = label [ style Styles.widthHeightLabel ] [ text (I18n.heightMeter lang) ]
  in
    div [ style Styles.floorSizeInputContainer ]
      [ widthLabel
      , widthValueView user useReal model.realWidthInput
      , heightLabel
      , heightValueView user useReal model.realHeightInput
      ]


inputAttributes : (String -> msg) -> (Int -> msg) -> String -> Maybe msg -> List (Attribute msg)
inputAttributes toInputMsg toKeydownMsg value_ defence =
  [ onInput_ toInputMsg -- TODO cannot input japanese
  , onKeyDown__ toKeydownMsg
  , value value_
  ] ++
    ( case defence of
        Just message -> [onMouseDown_ message]
        Nothing -> []
    )


onInput_ : (String -> a) -> Attribute a
onInput_ f =
  onWithOptions "input" { stopPropagation = True, preventDefault = True } (Decode.map f Html.Events.targetValue)


widthValueView : User -> Bool -> String -> Html Msg
widthValueView user useReal value =
  if User.isAdmin user then
    input
    ([ Html.Attributes.id "floor-real-width-input"
    , type_ "text"
    , disabled (not useReal)
    , style Styles.realSizeInput
    ] ++ (inputAttributes InputFloorRealWidth (always NoOp) value Nothing))
    []
  else
    div [ style Styles.floorWidthText ] [ text value ]


heightValueView : User -> Bool -> String -> Html Msg
heightValueView user useReal value =
  if User.isAdmin user then
    input
    ([ Html.Attributes.id "floor-real-height-input"
    , type_ "text"
    , disabled (not useReal)
    , style Styles.realSizeInput
    ] ++ (inputAttributes InputFloorRealHeight (always NoOp) value Nothing))
    []
  else
    div [ style Styles.floorHeightText ] [ text value ]


view : (Msg -> msg) -> Language -> User -> Floor -> FloorProperty -> Html msg -> Html msg -> Html msg -> Html msg -> List (Html msg)
view transform lang user floor model floorLoadButton publishButton deleteButton deleteDialog =
  [ floorLoadButton
  , Lazy.lazy3 floorNameInputView lang user model |> Html.map transform
  , Lazy.lazy3 floorOrdInputView lang user model |> Html.map transform
  , Lazy.lazy3 floorRealSizeInputView lang user model |> Html.map transform
  , publishButton
  , deleteButton
  , deleteDialog
  ]
