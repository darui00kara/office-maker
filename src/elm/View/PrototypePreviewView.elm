module View.PrototypePreviewView exposing (view, singleView, emptyView)

import Html exposing (..)
import Html.Attributes exposing (..)

import View.Styles as S
import View.ObjectView as ObjectView

import Model.Scale as Scale exposing (Scale)
import Model.Prototype exposing (Prototype)

type alias Size =
  { width : Int, height : Int }


view : Size -> Int -> List Prototype -> Html msg
view containerSize selectedIndex prototypes =
  let
    inner =
      div
        [ style (S.prototypePreviewViewInner containerSize.width selectedIndex) ]
        (List.indexedMap (eachView containerSize selectedIndex) prototypes)
  in
    div [ style (S.prototypePreviewView containerSize.width containerSize.height) ] [ inner ]


singleView : Size -> Prototype -> Html msg
singleView containerSize prototype =
  view containerSize 0 [ prototype ]


emptyView : Size -> Html msg
emptyView containerSize =
  view containerSize 0 []


eachView : Size -> Int -> Int -> Prototype -> Html msg
eachView containerSize selectedIndex index prototype =
  let
    selected =
      selectedIndex == index

    left =
      containerSize.width // 2 - prototype.width // 2 + index * containerSize.width

    top =
      containerSize.height // 2 - prototype.height // 2
  in
    ObjectView.viewDesk
      ObjectView.noEvents
      False
      (left, top, prototype.width, prototype.height)
      prototype.backgroundColor
      prototype.name --name
      prototype.fontSize
      False -- selected
      False -- alpha
      Scale.default
      True -- disableTransition
      False -- personMatched
