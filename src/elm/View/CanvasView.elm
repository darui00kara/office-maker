module View.CanvasView exposing (view, temporaryStampView)

import Dict exposing (..)
import Maybe

import Html exposing (..)
import Html.App as App
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as Keyed
import Html.Lazy exposing (..)

import ObjectNameInput
import View.Styles as S
import View.ObjectView as ObjectView
import View.ProfilePopup as ProfilePopup

import Util.HtmlUtil exposing (..)

import Update exposing (..)
import Model.Model as Model exposing (Model, ContextMenu(..), EditMode(..), DraggingContext(..), Tab(..))
import Model.Floor as Floor exposing (Floor)
import Model.Object as Object exposing (..)
import Model.Scale as Scale exposing (Scale)
import Model.ObjectsOperation as ObjectsOperation exposing (..)
import Model.Prototypes as Prototypes exposing (StampCandidate)

import Json.Decode as Decode


adjustImagePositionOfMovingObject : Int -> Scale -> (Int, Int) -> (Int, Int) -> (Int, Int) -> (Int, Int)
adjustImagePositionOfMovingObject gridSize scale (startX, startY) (x, y) (left, top) =
  let
    (dx, dy) =
      Scale.screenToImageForPosition scale ((x - startX), (y - startY))
  in
    fitPositionToGrid gridSize (left + dx, top + dy)


type alias ObjectViewOption =
  { editMode: EditMode
  , scale: Scale
  , selected: Bool
  , isGhost: Bool
  , object: Object
  , rect: (Int, Int, Int, Int)
  , contextMenuDisabled: Bool
  , disableTransition: Bool
  }


objectView : ObjectViewOption -> Html Msg
objectView {editMode, scale, selected, isGhost, object, rect, contextMenuDisabled, disableTransition} =
  let
    id =
      idOf object

    (x, y, width, height) =
      rect

    eventOptions =
      case editMode of
        Viewing _ ->
          let
            noEvents = ObjectView.noEvents
          in
            { noEvents |
              onMouseDown = Just (always (ShowDetailForObject id))
            }

        _ ->
          { onContextMenu =
              if contextMenuDisabled then
                Nothing
              else
                Just (ShowContextMenuOnObject id)
          , onMouseDown = Just (MouseDownOnObject id)
          , onMouseUp = Just (MouseUpOnObject id)
          , onStartEditingName = Nothing -- Just (StartEditObject id)
          , onStartResize = Just (MouseDownOnResizeGrip id)
          }

    personMatched =
      Object.relatedPerson object /= Nothing
  in
    if Object.isLabel object then
      ObjectView.viewLabel
        eventOptions
        (x, y, width, height)
        (backgroundColorOf object)
        (colorOf object)
        (nameOf object)
        (fontSizeOf object)
        (shapeOf object == Object.Ellipse)
        selected
        isGhost
        (editMode /= Viewing True && editMode /= Viewing False) -- rectVisible
        scale
        disableTransition
    else
      ObjectView.viewDesk
        eventOptions
        (editMode /= Viewing True && editMode /= Viewing False)
        (x, y, width, height)
        (backgroundColorOf object)
        (nameOf object)
        (fontSizeOf object)
        selected
        isGhost
        scale
        disableTransition
        personMatched


transitionDisabled : Model -> Bool
transitionDisabled model =
  not model.scaling


view : Model -> Html Msg
view model =
  case Model.getEditingFloor model of
    Just floor ->
      let
        popup' =
          Maybe.withDefault (text "") <|
          model.selectedResult `Maybe.andThen` \id ->
          findObjectById floor.objects id `Maybe.andThen` \e ->
            case Object.relatedPerson e of
              Just personId ->
                Dict.get personId model.personInfo `Maybe.andThen` \person ->
                Just (ProfilePopup.view ClosePopup model.personPopupSize model.scale model.offset e (Just person))
                
              Nothing ->
                Just (ProfilePopup.view ClosePopup model.personPopupSize model.scale model.offset e Nothing)

        isRangeSelectMode =
          model.editMode == Select && model.keys.ctrl
      in
        div
          [ style (S.canvasContainer (model.editMode == Viewing True) isRangeSelectMode)
          , onMouseMove' MoveOnCanvas
          , onWithOptions "mousedown" { stopPropagation = True, preventDefault = False } (Decode.map MouseDownOnCanvas decodeClientXY)
          , onWithOptions "mouseup" { stopPropagation = True, preventDefault = False } (Decode.succeed MouseUpOnCanvas)
          , onMouseEnter' EnterCanvas
          , onMouseLeave' LeaveCanvas
          , onMouseWheel MouseWheel
          ]
          [ canvasView model floor, popup']

    Nothing ->
      div
        [ style (S.canvasContainer (model.editMode == Viewing True) False)
        ] []


canvasView : Model -> Floor -> Html Msg
canvasView model floor =
  let
    (isViewing, isPrintMode) =
      case model.editMode of
        Viewing print -> (True, print)
        _ -> (False, False)

    objects =
      objectsView model floor

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

    deskInfoOf model id =
      Maybe.map
        (\e ->
          let
            id = idOf e
            maybePersonId = relatedPerson e
          in
            ( Scale.imageToScreenForRect model.scale (Object.rect e)
            , maybePersonId `Maybe.andThen` (\id -> Dict.get id model.personInfo)
            )
        )
        (findObjectById floor.objects id)

    nameInput =
      App.map ObjectNameInputMsg <|
        ObjectNameInput.view
          (deskInfoOf model)
          (transitionDisabled model)
          (Model.candidatesOf model)
          model.objectNameInput

    children1 =
      ("canvas-image", image) ::
      ("canvas-name-input", nameInput) ::
      ("canvas-selector-rect", selectorRect) ::
      objects

    children2 =
      ("canvas-temporary-pen", temporaryPen') ::
      temporaryStamps'

    styles =
      if isPrintMode then
        S.canvasViewForPrint model.windowSize rect
      else
        S.canvasView isViewing (transitionDisabled model) rect

  in
    Keyed.node
      "div"
      [ style styles ]
      ( children1 ++ children2 )


objectsView : Model -> Floor -> List (String, Html Msg)
objectsView model floor =
  case model.draggingContext of
    MoveObject _ from ->
      let
        isSelected object =
          List.member (idOf object) model.selectedObjects

        ghostsView =
          List.map
            (\object ->
              ( idOf object ++ "ghost"
              , lazy objectView
                  { editMode = model.editMode
                  , scale = model.scale
                  , rect = rect object
                  , selected = True
                  , isGhost = True -- alpha
                  , object = object
                  , contextMenuDisabled = False --model.keys.ctrl
                  , disableTransition = transitionDisabled model
                  }
              )
            )
            (List.filter isSelected floor.objects)

        adjustRect object (left, top, width, height) =
          if isSelected object then
            let
              (x, y) =
                adjustImagePositionOfMovingObject
                  model.gridSize
                  model.scale
                  from
                  model.pos
                  (left, top)
            in
              (x, y, width, height)
          else
            (left, top, width, height)

        normalView =
          List.map
            (\object ->
              ( idOf object
              , lazy
                objectView
                  { editMode = model.editMode
                  , scale = model.scale
                  , rect = adjustRect object (rect object)
                  , selected = isSelected object
                  , isGhost = False
                  , object = object
                  , contextMenuDisabled = model.keys.ctrl
                  , disableTransition = transitionDisabled model
                  }
              )
            )
            floor.objects
      in
        (ghostsView ++ normalView)

    ResizeFromScreenPos id from ->
      let
        isSelected object =
          List.member (idOf object) model.selectedObjects

        isResizing object =
          idOf object == id

        ghostsView =
          List.map
            (\object ->
              ( idOf object ++ "ghost"
              , lazy objectView
                { editMode = model.editMode
                , scale = model.scale
                , rect = rect object
                , selected = True
                , isGhost = True
                , object = object
                , contextMenuDisabled = model.keys.ctrl
                , disableTransition = transitionDisabled model
                }
              )
            )
            (List.filter isResizing floor.objects)

        adjustRect object (left, top, width, height) =
          if isResizing object then
            case Model.temporaryResizeRect model from (left, top, width, height) of
              Just rect -> rect
              _ -> (0,0,0,0)
          else
            (left, top, width, height)

        normalView =
          List.map
            (\object ->
              ( idOf object
              , lazy objectView
                { editMode = model.editMode
                , scale = model.scale
                , rect = adjustRect object (rect object)
                , selected = isResizing object --TODO seems not selected?
                , isGhost = False
                , object = object
                , contextMenuDisabled = model.keys.ctrl
                , disableTransition = transitionDisabled model
                }
              )
            )
            floor.objects
      in
        (normalView ++ ghostsView)

    _ ->
      List.map
        (\object ->
          ( idOf object
          , lazy objectView
            { editMode = model.editMode
            , scale = model.scale
            , rect = (rect object)
            , selected = Model.isSelected model object --TODO seems not selected?
            , isGhost = False
            , object = object
            , contextMenuDisabled = model.keys.ctrl
            , disableTransition = transitionDisabled model
            }
          )
        )
        floor.objects


canvasImage : Floor -> Html msg
canvasImage floor =
  img
    [ style S.canvasImage
    , src (Maybe.withDefault "" (Floor.src floor))
    ] []


temporaryStampView : Scale -> Bool -> StampCandidate -> (String, Html msg)
temporaryStampView scale selected (prototype, (left, top)) =
  let
    (deskWidth, deskHeight) = prototype.size
  in
    ( "temporary_" ++ toString left ++ "_" ++ toString top ++ "_" ++ toString deskWidth ++ "_" ++ toString deskHeight
    , ObjectView.viewDesk
        ObjectView.noEvents
        False
        (left, top, deskWidth, deskHeight)
        prototype.backgroundColor
        prototype.name --name
        Object.defaultFontSize
        selected
        False -- alpha
        scale
        True -- disableTransition
        False -- personMatched
    )


temporaryPenView : Model -> (Int, Int) -> Html msg
temporaryPenView model from =
  case Model.temporaryPen model from of
    Just (color, name, (left, top, width, height)) ->
      ObjectView.viewDesk
        ObjectView.noEvents
        False
        (left, top, width, height)
        color
        name --name
        Object.defaultFontSize
        False -- selected
        False -- alpha
        model.scale
        True -- disableTransition
        False -- personMatched
    Nothing ->
      text ""


temporaryStampsView : Model -> List (String, Html msg)
temporaryStampsView model =
  List.map
    (temporaryStampView model.scale False)
    (Model.stampCandidates model)

--
