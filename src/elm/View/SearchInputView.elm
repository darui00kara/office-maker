module View.SearchInputView exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy as Lazy
import Model.I18n as I18n exposing (Language)

import View.Styles as S

import Util.HtmlUtil as HtmlUtil

view : Language -> (String -> msg) -> msg -> String -> Html msg
view lang onInputMsg onSubmit query =
  HtmlUtil.form_ onSubmit
    [ style S.searchBoxContainer ]
    [ Lazy.lazy3 textInput lang onInputMsg query
    , submitButton
    ]


textInput : Language -> (String -> msg) -> String -> Html msg
textInput lang onInputMsg query =
  input
      [ type_ "input"
      , placeholder (I18n.search lang)
      , style S.searchBox
      , defaultValue query
      , HtmlUtil.onInput onInputMsg
      ]
      []


submitButton : Html msg
submitButton =
  input
    [ type_ "submit"
    , style S.searchBoxSubmit
    , value "Search"
    ]
    []
