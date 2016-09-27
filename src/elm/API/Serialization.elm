module API.Serialization exposing (..)

import Date

import Json.Encode as E exposing (Value)
import Json.Decode as D exposing ((:=), Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded, custom)

import Util.DecodeUtil exposing (..)

import Model.Floor as Floor exposing (Floor)
import Model.FloorDiff as FloorDiff exposing (..)
import Model.FloorInfo as FloorInfo exposing (FloorInfo)
import Model.User as User exposing (User)
import Model.Person exposing (Person)
import Model.Object as Object exposing (..)
import Model.Prototype exposing (Prototype)
import Model.SearchResult exposing (SearchResult)
import Model.ColorPalette as ColorPalette exposing (ColorPalette, ColorEntity)


decodeAuthToken : Decoder String
decodeAuthToken =
  D.object1 identity ("accessToken" := D.string)


decodeColors : Decoder ColorPalette
decodeColors =
  D.map ColorPalette.init (D.list decodeColorEntity)


decodePrototypes : Decoder (List Prototype)
decodePrototypes =
  D.list decodePrototype


decodeFloors : Decoder (List Floor)
decodeFloors =
  D.list decodeFloor


decodeFloorInfoList : Decoder (List FloorInfo)
decodeFloorInfoList =
  D.list decodeFloorInfo


decodePeople : Decoder (List Person)
decodePeople =
  D.list decodePerson


encodeObject : Object -> Value
encodeObject e =
  case e of
    Desk id (x, y, width, height) backgroundColor name personId ->
      E.object
        [ ("id", E.string id)
        , ("type", E.string "desk")
        , ("x", E.int x)
        , ("y", E.int y)
        , ("width", E.int width)
        , ("height", E.int height)
        , ("backgroundColor", E.string backgroundColor)
        , ("color", E.string "#000")
        , ("shape", E.string "rectangle")
        , ("name", E.string name)
        , ("fontSize", E.float Object.defaultFontSize)
        , ("personId"
          , case personId of
              Just id -> E.string id
              Nothing -> E.null
          )
        ]

    Label id (x, y, width, height) bgColor name fontSize color shape ->
      E.object
        [ ("id", E.string id)
        , ("type", E.string "label")
        , ("x", E.int x)
        , ("y", E.int y)
        , ("width", E.int width)
        , ("height", E.int height)
        , ("backgroundColor", E.string bgColor)
        , ("name", E.string name)
        , ("fontSize", E.float fontSize)
        , ("color", E.string color)
        , ("shape", E.string (encodeShape shape))
        ]

encodeShape : Shape -> String
encodeShape shape =
  case shape of
    Object.Rectangle ->
      "rectangle"

    Object.Ellipse ->
      "ellipse"


encodeObjectModification : ObjectModification -> Value
encodeObjectModification mod =
  E.object
    [ ("old", encodeObject mod.old)
    , ("new", encodeObject mod.new)
    ]


encodeFloor : Floor -> ObjectsChange -> Value
encodeFloor floor change =
  E.object
    [ ("id", E.string floor.id)
    , ("version", E.int floor.version)
    , ("name", E.string floor.name)
    , ("ord", E.int floor.ord)
    , ("added", E.list (List.map encodeObject change.added))
    , ("modified", E.list (List.map encodeObjectModification change.modified))
    , ("deleted", E.list (List.map encodeObject change.deleted))
    , ("width", E.int floor.width)
    , ("height", E.int floor.height)
    , ("realWidth", Maybe.withDefault E.null <| Maybe.map (E.int << fst) floor.realSize)
    , ("realHeight", Maybe.withDefault E.null <| Maybe.map (E.int << snd) floor.realSize)
    , ("image", Maybe.withDefault E.null <| Maybe.map E.string floor.image)
    , ("public", E.bool floor.public)
    ]


encodeLogin : String -> String -> Value
encodeLogin userId pass =
  E.object
    [ ("userId", E.string userId)
    , ("password", E.string pass)
    ]


decodeUser : Decoder User
decodeUser =
  D.oneOf
    [ D.object2
        (\role person ->
          if role == "admin" then User.admin person else User.general person
        )
        ("role" := D.string)
        ("person" := decodePerson)
    , D.succeed User.guest
    ]


decodeColorEntity : Decoder ColorEntity
decodeColorEntity =
  decode
    ColorEntity
    |> required "id" D.string
    |> required "ord" D.int
    |> required "type" D.string
    |> required "color" D.string


decodePerson : Decoder Person
decodePerson =
  decode
    (\id name org mail tel image ->
      { id = id, name = name, org = org, mail = mail, tel = tel, image = image}
    )
    |> required "id" D.string
    |> required "name" D.string
    |> required "org" D.string
    |> optional' "mail" D.string
    |> optional' "tel" D.string
    |> optional' "image" D.string


 -- TODO andThen
decodeObject : Decoder Object
decodeObject =
  decode
    (\id tipe x y width height backgroundColor name personId fontSize color shape ->
      if tipe == "desk" then
        Desk id (x, y, width, height) backgroundColor name personId
      else
        Label id (x, y, width, height) backgroundColor name fontSize color
          (if shape == "rectangle" then
            Object.Rectangle
          else
            Object.Ellipse
          )
    )
    |> required "id" D.string
    |> required "type" D.string
    |> required "x" D.int
    |> required "y" D.int
    |> required "width" D.int
    |> required "height" D.int
    |> required "backgroundColor" D.string
    |> required "name" D.string
    |> optional' "personId" D.string
    |> optional "fontSize" D.float 0
    |> required "color" D.string
    |> required "shape" D.string


decodeSearchResult : Decoder SearchResult
decodeSearchResult =
  decode
    SearchResult
    |> optional' "personId" D.string
    |> optional' "objectIdAndFloorId" (D.tuple2 (,) decodeObject D.string)


decodeSearchResults : Decoder (List SearchResult)
decodeSearchResults =
  D.list decodeSearchResult


decodeFloor : Decoder Floor
decodeFloor =
  decode
    (\id version name ord objects width height realWidth realHeight image public updateBy updateAt ->
      { id = id
      , version = version
      , name = name
      , ord = ord
      , objects = objects
      , width = width
      , height = height
      , image = image
      , realSize = Maybe.map2 (,) realWidth realHeight
      , public = public
      , update = Maybe.map2 (\by at -> { by = by, at = Date.fromTime at }) updateBy updateAt
      })
    |> required "id" D.string
    |> required "version" D.int
    |> required "name" D.string
    |> required "ord" D.int
    |> required "objects" (D.list decodeObject)
    |> required "width" D.int
    |> required "height" D.int
    |> optional' "realWidth" D.int
    |> optional' "realHeight" D.int
    |> optional' "image" D.string
    |> optional "public" D.bool False
    |> optional' "updateBy" D.string
    |> optional' "updateAt" D.float


decodeFloorInfo : Decoder FloorInfo
decodeFloorInfo = D.map (\(lastFloor, lastFloorWithEdit) ->
  if lastFloorWithEdit.public then
    FloorInfo.Public lastFloorWithEdit
  else if lastFloor.public then
    FloorInfo.PublicWithEdit lastFloor lastFloorWithEdit
  else
    FloorInfo.Private lastFloorWithEdit
  ) (D.tuple2 (,) decodeFloor decodeFloor)


decodePrototype : Decoder Prototype
decodePrototype =
  decode
    (\id backgroundColor color name width height fontSize shape ->
      { id = id
      , name = name
      , backgroundColor = backgroundColor
      , color = color
      , size = (width, height)
      , fontSize = fontSize
      , shape = if shape == "Ellipse" then Ellipse else Rectangle
      }
    )
    |> required "id" D.string
    |> required "backgroundColor" D.string
    |> required "color" D.string
    |> required "name" D.string
    |> required "width" D.int
    |> required "height" D.int
    |> required "fontSize" D.float
    |> required "shape" D.string


encodePrototype : Prototype -> Value
encodePrototype { id, color, backgroundColor, name, size, fontSize, shape } =
  let
    (width, height) = size
  in
    E.object
      [ ("id", E.string id)
      , ("color", E.string color)
      , ("backgroundColor", E.string backgroundColor)
      , ("name", E.string name)
      , ("width", E.int width)
      , ("height", E.int height)
      , ("fontSize", E.float fontSize)
      , ("shape", E.string (encodeShape shape))
      ]


serializePrototypes : List Prototype -> String
serializePrototypes prototypes =
  E.encode 0 (E.list (List.map encodePrototype prototypes))


serializeFloor : Floor -> ObjectsChange -> String
serializeFloor floor change =
    E.encode 0 (encodeFloor floor change)


serializeLogin : String -> String -> String
serializeLogin userId pass =
    E.encode 0 (encodeLogin userId pass)
