module Styles where

--import Html.Attributes exposing (Attributes, style)

type alias S = List (String, String)

zIndex :
  { selectedDesk : String
  , deskInput : String
  , selectorRect : String
  , subMenu : String
  , contextMenu : String
  }
zIndex =
  { selectedDesk = "100"
  , deskInput = "200"
  , selectorRect = "300"
  , subMenu = "600"
  , contextMenu = "800"
  }

noMargin : S
noMargin =
  [ ( "margin", "0") ]

noPadding : S
noPadding =
  [ ( "padding", "0") ]

flex : S
flex =
  [ ( "display", "flex") ]

h1 : S
h1 =
  noMargin ++
    [ ( "font-size", "1.4em")
    , ("font-weight", "normal")
    , ("line-height", toString headerHeight ++ "px")
    ]

ul : S
ul =
  [ ("list-style-type", "none")
  , ("padding-left", "0") ]

headerHeight : Int
headerHeight = 37

header : S
header =
  noMargin ++
    [ ( "background", "rgb(100, 180, 85)")
    , ("color", "#eee")
    , ("height", toString headerHeight ++ "px")
    , ("padding-left", "10px")
    ]

rect : (Int, Int, Int, Int) -> S
rect (x, y, w, h) =
  [ ("top", toString y ++ "px")
  , ("left", toString x ++ "px")
  , ("width", toString w ++ "px")
  , ("height", toString h ++ "px")
  ]

absoluteRect : (Int, Int, Int, Int) -> S
absoluteRect rect' =
  ("position", "absolute") :: (rect rect')

deskInput : (Int, Int, Int, Int) -> S
deskInput rect =
  (absoluteRect rect) ++ noPadding ++ [ ("z-index", zIndex.deskInput)
  , ("box-sizing", "border-box")
  ]

desk : (Int, Int, Int, Int) -> String -> Bool -> Bool -> S
desk rect color selected alpha =
  (absoluteRect rect) ++ [ ("opacity", if alpha then "0.5" else "1.0")
  , ("background-color", color)
  , ("box-sizing", "border-box")
  , ("z-index", if selected then zIndex.selectedDesk else "")
  , ("border-style", "solid")
  , ("border-width", if selected  then "2px" else "1px")
  , ("border-color", if selected  then "#69e" else "#666")
  ]

selectorRect : (Int, Int, Int, Int) -> S
selectorRect rect =
  (absoluteRect rect) ++ [("z-index", zIndex.selectorRect)
  , ("border-style", "solid")
  , ("border-width", "2px")
  , ("border-color", "#69e")
  ]

colorProperty : String -> Bool -> S
colorProperty color selected =
  [ ("background-color", color)
  , ("cursor", "pointer")
  , ("width", "30px")
  , ("height", "30px")
  , ("box-sizing", "border-box")
  , ("border-style", "solid")
  , ("margin-right", "2px")
  , ("border-width", if selected  then "2px" else "1px")
  , ("border-color", if selected  then "#69e" else "#666")
  ]

subMenu : S
subMenu =
    [ ("z-index", zIndex.subMenu)
    , ("width", "300px")
    , ("overflow", "hidden")
    , ("background", "#eee")
    ]

contextMenu : (Int, Int) -> (Int, Int) -> Int -> S
contextMenu (x, y) (windowWidth, windowHeight) rows =
  let
    width = 200
    height = rows * 20 --TODO
    x' = min x (windowWidth - width)
    y' = min y (windowHeight - height)
  in
    [ ("width", toString width ++ "px")
    , ("left", toString x' ++ "px")
    , ("top", toString y' ++ "px")
    , ("position", "fixed")
    , ("z-index", zIndex.contextMenu)
    , ("background-color", "#fff")
    , ("box-sizing", "border-box")
    , ("border-style", "solid")
    , ("border-width", "1px")
    , ("border-color", "#eee")
    ]

contextMenuItem : S
contextMenuItem =
  [ ("padding", "5px")
  ]

canvasView : (Int, Int, Int, Int) -> S
canvasView rect =
  (absoluteRect rect) ++
    [ ("background-color", "#fff")
    , ("overflow", "hidden")
    , ("font-family", "default")
    ]

canvasContainer : S
canvasContainer =
  [ ("position", "relative")
  , ("overflow", "hidden")
  , ("background", "#000")
  , ("flex", "1")
  ]

nameLabel : Float -> S
nameLabel ratio =
  [ ("display", "table-cell")
  , ("vertical-align", "middle")
  , ("text-align", "center")
  , ("position", "absolute")
  , ("cursor", "default")
  , ("font-size", toString ratio ++ "em") --TODO
   -- TODO vertical align
  ]

shadow : S
shadow =
  [ ("box-shadow", "0 2px 2px 0 rgba(0,0,0,.14),0 3px 1px -2px rgba(0,0,0,.2),0 1px 5px 0 rgba(0,0,0,.12)") ]

card : S
card =
  [ ("margin", "5px")
  , ("padding", "5px")
  ] ++ shadow

selection : Bool -> S
selection selected =
  [ ("cursor", "pointer")
  , ("padding", "10px")
  , ("text-align", "center")
  , ("box-sizing", "border-box")
  , ("margin-right", "-1px")
  , ("border", "solid 1px #666")
  , ("background-color", if selected then "#69e" else "inherit")
  , ("color", if selected then "#fff" else "inherit")
  -- , ("font-weight", if selected then "bold" else "inherit")
  ]

transition : Bool -> S
transition disabled =
  if disabled then [] else
    [ ("transition-property", "width, height, top, left")
    , ("transition-duration", "0.2s")
    ]

prototypePreviewView : Bool -> S
prototypePreviewView stampMode =
  [ ("width", "238px")
  , ("height", "238px")
  , ("position", "relative")
  , ("border-style", "solid")
  , ("border-width", if stampMode then "2px" else "1px")
  , ("border-color", if stampMode then "#69e" else "#666")
  , ("box-sizing", "border-box")
  , ("margin-top", "10px")
  , ("background-color", "#fff")
  , ("overflow", "hidden")
  ]

prototypePreviewViewInner : Int -> S
prototypePreviewViewInner index =
  [ ("width", "238px")
  , ("height", "238px")
  , ("position", "relative")
  , ("top", "0")
  , ("left", toString (index * -238) ++ "px")
  , ("transition-property", "left")
  , ("transition-duration", "0.2s")
  ]

prototypePreviewScroll : S
prototypePreviewScroll =
  [ ("width", "30px")
  , ("height", "30px")
  , ("font-size", "large")
  , ("font-weight", "bold")
  , ("line-height", "30px")
  , ("position", "absolute")
  , ("top", "104px")
  , ("border-radius", "15px")
  , ("text-align", "center")
  , ("color", "#fff")
  , ("background-color", "#ccc")
  , ("cursor", "pointer")
  ]
