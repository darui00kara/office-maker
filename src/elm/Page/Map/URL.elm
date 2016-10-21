module Page.Map.URL exposing (..)

import Dict
import String

import Navigation

import Model.EditingFloor as EditingFloor
import Model.EditMode as EditMode exposing (EditMode(..))
import Util.UrlParser as UrlParser

import Page.Map.Model as Model exposing (Model)


type alias URL =
  { floorId: Maybe String
  , query : Maybe String
  , editMode : Bool
  }


parse : Navigation.Location -> Result String URL
parse location =
  let
    floorId =
      if String.startsWith "#" location.hash then
        let
          id =
            String.dropLeft 1 location.hash
        in
          if String.length id == 36 then
            Ok (Just id)
          else if String.length id == 0 then
            Ok Nothing
          else
            Err ("invalid floorId: " ++ id)
      else
        Ok Nothing

    dict =
      UrlParser.parseSearch location.search
  in
    case floorId of
      Ok floorId ->
        Ok <|
          { floorId = floorId
          , query = Dict.get "q" dict
          , editMode = Dict.member "edit" dict
          }

      Err s ->
        Err s


init : URL
init =
  { floorId = Nothing
  , query = Nothing
  , editMode = False
  }


stringify : URL -> String
stringify { floorId, query, editMode } =
  let
    params =
      (List.filterMap
        (\(key, maybeValue) -> Maybe.map (\v -> (key, v)) maybeValue)
        [ ("q", query)
        ]
      ) ++ (if editMode then [ ("edit", "true") ] else [])
  in
    case floorId of
      Just id ->
        stringifyParams params ++ "#" ++ id

      Nothing ->
        stringifyParams params


stringifyParams : List (String, String) -> String
stringifyParams params =
  if params == [] then
    ""
  else
    "?" ++
      ( String.join "&" <|
        List.map (\(k, v) -> k ++ "=" ++ v) params
      )


fromModel : Model -> URL
fromModel model =
  { floorId = Maybe.map (\floor -> (EditingFloor.present floor).id) model.floor
  , query =
      if String.length model.searchQuery == 0 then
        Nothing
      else
        Just model.searchQuery
  , editMode =
      case model.editMode of
        Viewing _ -> False
        _ -> True
  }


serialize : Model -> String
serialize =
  stringify << fromModel



--