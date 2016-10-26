module Page.Map.SearchResultView exposing (..)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events
import Model.Object exposing (..)
import Model.Floor exposing (Floor, FloorBase)
import Model.FloorInfo as FloorInfo exposing (FloorInfo(..))
import Model.Person exposing (Person)
import Model.EditMode as EditMode exposing (EditMode(..))
import Model.SearchResult exposing (SearchResult)
import Model.I18n as I18n exposing (Language)

import View.SearchResultItemView as SearchResultItemView exposing (Item(..))
import View.Icons as Icons
import View.Styles as S

import Page.Map.Model exposing (Model, ContextMenu(..), DraggingContext(..), Tab(..))
import Page.Map.Update exposing (Msg(..))


view : (SearchResult -> Msg) -> Model -> Html Msg
view onSelectResult model =
  let
    floorsInfoDict =
      Dict.fromList <|
        List.map (\f ->
          case f of
            Public f -> (f.id, f)
            PublicWithEdit _ f -> (f.id, f)
            Private f -> (f.id, f)
          ) model.floorsInfo

    format =
      formatSearchResult model.lang floorsInfoDict model.personInfo model.selectedResult

    isEditing =
      model.editMode /= Viewing True && model.editMode /= Viewing False
  in
    view' model.lang onSelectResult isEditing format model.searchResult



view' : Language -> (SearchResult -> msg) -> Bool -> (SearchResult -> Html msg) -> (Maybe (List SearchResult)) -> Html msg
view' lang onSelectResult isEditing format maybeResults =
    case maybeResults of
      Nothing ->
        text ""

      Just [] ->
        div [] [ text (I18n.nothingFound lang) ]

      Just results ->
        let
          each result =
            viewEach onSelectResult format result

          children =
            List.map each results
        in
          ul [] children


viewEach : (SearchResult -> msg) -> (SearchResult -> Html msg) -> SearchResult -> Html msg
viewEach onSelectResult format result =
    li
      [ Html.Events.onClick (onSelectResult result)
      , style S.searchResultItem
      ]
      [ format result ]


formatSearchResult : Language -> Dict String FloorBase -> Dict String Person -> Maybe Id -> SearchResult -> Html Msg
formatSearchResult lang floorsInfo personInfo currentlyFocusedObjectId = \result ->
  let
    maybeItem =
      case (result.objectIdAndFloorId, result.personId) of
        (Just (e, fid), Just personId) ->
          case (Dict.get fid floorsInfo, Dict.get personId personInfo) of
            (Just info, Just person) ->
              Just (SearchResultItemView.Object (nameOf e) info.name (Just person.name) (Just (idOf e) == currentlyFocusedObjectId))

            _ ->
              Nothing

        (Just (e, floorId), _) ->
          case Dict.get floorId floorsInfo of
            Just info ->
              Just (SearchResultItemView.Object (nameOf e) info.name Nothing (Just (idOf e) == currentlyFocusedObjectId))

            _ ->
              Nothing

        (Nothing, Just personId) ->
          case Dict.get personId personInfo of
            Just person -> Just (SearchResultItemView.MissingPerson person.name)
            Nothing -> Nothing

        _ ->
          Nothing
  in
    case maybeItem of
      Just item ->
        SearchResultItemView.view lang False item

      Nothing ->
        text ""
