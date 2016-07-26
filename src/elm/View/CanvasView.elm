module View.CanvasView exposing (view, temporaryStampView)

import Dict exposing (..)
import Maybe

import Html exposing (..)
import Html.App as App
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as Keyed

import EquipmentNameInput
import View.Styles as S
import View.EquipmentView as EquipmentView
import View.ProfilePopup as ProfilePopup

import Util.HtmlUtil exposing (..)

import Model exposing (..)
import Model.Floor as Floor
import Model.Equipments as Equipments exposing (..)
import Model.Scale as Scale
import Model.EquipmentsOperation as EquipmentsOperation exposing (..)
import Model.Prototypes as Prototypes exposing (Prototype, StampCandidate)
import Model.Person exposing (Person)


adjustImagePositionOfMovingEquipment : Int -> Scale.Model -> Maybe ((Int, Int), (Int, Int)) -> (Int, Int) -> (Int, Int)
adjustImagePositionOfMovingEquipment gridSize scale moving (left, top) =
  case moving of
    Just ((startX, startY), (x, y)) ->
      let
        (dx, dy) =
          Scale.screenToImageForPosition scale ((x - startX), (y - startY))
      in
        fitToGrid gridSize (left + dx, top + dy)

    _ -> (left, top)


equipmentView : Model -> Maybe ((Int, Int), (Int, Int)) -> Bool -> Bool -> Equipment -> Bool -> Bool -> (String, Html Msg)
equipmentView model moving selected alpha equipment contextMenuDisabled disableTransition =
  case equipment of
    Desk id (left, top, width, height) color name personId ->
      let
        movingBool =
          moving /= Nothing

        (x, y) =
          adjustImagePositionOfMovingEquipment
            model.gridSize
            model.scale
            moving
            (left, top)

        eventOptions =
          case model.editMode of
            Viewing _ ->
              let
                noEvents = EquipmentView.noEvents
              in
                { noEvents |
                  onMouseDown = Just (ShowDetailForEquipment id)
                }
            _ ->
              { onContextMenu =
                  if contextMenuDisabled then
                    Nothing
                  else
                    Just (ShowContextMenuOnEquipment id)
              , onMouseDown = Just (MouseDownOnEquipment id)
              , onMouseUp = Just (MouseUpOnEquipment id)
              , onStartEditingName = Nothing -- Just (StartEditEquipment id)
              , onStartResize = Just (MouseDownOnResizeGrip id)
              }

        floor =
          model.floor.present

        personInfo =
          model.selectedResult `Maybe.andThen` \id' ->
            if id' == id then
              findEquipmentById floor.equipments id `Maybe.andThen` \equipment ->
              Equipments.relatedPerson equipment `Maybe.andThen` \personId ->
              Dict.get personId model.personInfo
            else
              Nothing

        personMatched =
          personId /= Nothing
      in
        ( id ++ toString movingBool
        , EquipmentView.view
            eventOptions
            (model.editMode /= Viewing True && model.editMode /= Viewing False)
            (x, y, width, height)
            color
            name
            selected
            alpha
            model.scale
            disableTransition
            personInfo
            personMatched
        )


transitionDisabled : Model -> Bool
transitionDisabled model =
  not model.scaling


view : Model -> Html Msg
view model =
  let
    floor =
      model.floor.present

    popup' =
      Maybe.withDefault (text "") <|
      model.selectedResult `Maybe.andThen` \id ->
      findEquipmentById floor.equipments id `Maybe.andThen` \e ->
        case Equipments.relatedPerson e of
          Just personId ->
            Dict.get personId model.personInfo `Maybe.andThen` \person ->
            Just (ProfilePopup.view ClosePopup model.personPopupSize model.scale model.offset e (Just person))
          Nothing ->
            Just (ProfilePopup.view ClosePopup model.personPopupSize model.scale model.offset e Nothing)

    inner =
      case (model.editMode, model.floor.present.id) of
        (Viewing _, Nothing) ->
          [] -- don't show draft on Viewing mode
        _ ->
          [ canvasView model, popup']
  in
    div
      [ style (S.canvasContainer (model.editMode == Viewing True) ++
        ( if model.editMode == Stamp then
            [] -- [("cursor", "none")]
          else
            []
        ))
      , onMouseMove' MoveOnCanvas
      , onMouseDown MouseDownOnCanvas
      , onMouseUp MouseUpOnCanvas
      , onMouseEnter' EnterCanvas
      , onMouseLeave' LeaveCanvas
      , onMouseWheel MouseWheel
      ]
      inner


canvasView : Model -> Html Msg
canvasView model =
  let
    floor =
      model.floor.present

    isViewing =
      case model.editMode of
        Viewing _ -> True
        _ -> False

    equipments =
      equipmentsView model

    selectorRect =
      case (model.editMode, model.selectorRect) of
        (Select, Just rect) ->
          div [style (S.selectorRect (transitionDisabled model) (Scale.imageToScreenForRect model.scale rect) )] []
        _ -> text ""

    temporaryStamps' =
      temporaryStampsView model

    temporaryPen' =
      case model.draggingContext of
        PenFromScreenPos (x, y) ->
          temporaryPenView model (x, y)
        _ -> text ""

    (offsetX, offsetY) = model.offset

    rect =
      Scale.imageToScreenForRect
        model.scale
        (offsetX, offsetY, Floor.width floor, Floor.height floor)

    image =
      canvasImage floor

    nameInput =
      App.map EquipmentNameInputMsg <|
        EquipmentNameInput.view
          (deskInfoOf model)
          (transitionDisabled model)
          (candidatesOf model)
          model.equipmentNameInput

    children1 =
      ("canvas-image", image) ::
      ("canvas-name-input", nameInput) ::
      ("canvas-selector-rect", selectorRect) ::
      equipments

    children2 =
      ("canvas-temporary-pen", temporaryPen') ::
      temporaryStamps'

  in
    Keyed.node
      "div"
      [ style (S.canvasView isViewing (transitionDisabled model) rect)
      ]
      ( children1 ++ children2 )


equipmentsView : Model -> List (String, Html Msg)
equipmentsView model =
  case model.draggingContext of
    MoveEquipment _ from ->
      let
        isSelected equipment =
          List.member (idOf equipment) model.selectedEquipments

        ghostsView =
          List.map
            (\equipment ->
              equipmentView
                model
                -- (Just (from, model.pos)) -- moving
                Nothing
                True
                True -- alpha
                equipment
                model.keys.ctrl
                (transitionDisabled model)
            )
            (List.filter isSelected (model.floor.present.equipments))

        normalView =
          List.map
            (\equipment ->
              equipmentView
                model
                (if isSelected equipment then Just (from, model.pos) else Nothing ) -- moving
                (isSelected equipment)
                False -- alpha
                equipment
                model.keys.ctrl
                (transitionDisabled model)
            )
            (model.floor.present.equipments)
      in
        (ghostsView ++ normalView)
    _ ->
      List.map
        (\equipment ->
          equipmentView
            model
            Nothing -- moving
            (isSelected model equipment)
            False -- alpha
            equipment
            model.keys.ctrl
            (transitionDisabled model)
        )
        (model.floor.present.equipments)


canvasImage : Floor -> Html msg
canvasImage floor =
  img
    [ style S.canvasImage
    , src (Maybe.withDefault "" (Floor.src floor))
    ] []


deskInfoOf : Model -> String -> Maybe ((Int, Int, Int, Int), Maybe Person)
deskInfoOf model id =
  findEquipmentById model.floor.present.equipments id
  |> Maybe.map (\(Desk id rect _ _ maybePersonId) ->
    ( Scale.imageToScreenForRect model.scale rect
    , maybePersonId `Maybe.andThen` (\id -> Dict.get id model.personInfo)
    ))


temporaryStampView : Scale.Model -> Bool -> StampCandidate -> (String, Html msg)
temporaryStampView scale selected ((prototypeId, color, name, (deskWidth, deskHeight)), (left, top)) =
  ( "temporary_" ++ toString left ++ "_" ++ toString top ++ "_" ++ toString deskWidth ++ "_" ++ toString deskHeight
  , EquipmentView.view
      EquipmentView.noEvents
      False
      (left, top, deskWidth, deskHeight)
      color
      name --name
      selected
      False -- alpha
      scale
      True -- disableTransition
      Nothing
      False -- personMatched
  )


temporaryPenView : Model -> (Int, Int) -> Html msg
temporaryPenView model from =
  case temporaryPen model from of
    Just (color, name, (left, top, width, height)) ->
      EquipmentView.view
        EquipmentView.noEvents
        False
        (left, top, width, height)
        color
        name --name
        False -- selected
        False -- alpha
        model.scale
        True -- disableTransition
        Nothing
        False -- personMatched
    Nothing ->
      text ""


temporaryStampsView : Model -> List (String, Html msg)
temporaryStampsView model =
  List.map
    (temporaryStampView model.scale False)
    (stampCandidates model)

--
