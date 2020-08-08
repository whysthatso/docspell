module Comp.TagSelect exposing
    ( Category
    , Model
    , Msg
    , Selection
    , emptySelection
    , init
    , update
    , view
    )

import Api.Model.TagCount exposing (TagCount)
import Data.Icons as I
import Data.UiSettings exposing (UiSettings)
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)


type alias Model =
    { all : List TagCount
    , categories : List Category
    , selectedTags : Dict String Bool
    , selectedCats : Dict String Bool
    , expandedTags : Bool
    , expandedCats : Bool
    }


type alias Category =
    { name : String
    , count : Int
    }


init : List TagCount -> Model
init tags =
    { all = tags
    , categories = sumCategories tags
    , selectedTags = Dict.empty
    , selectedCats = Dict.empty
    , expandedTags = False
    , expandedCats = False
    }


sumCategories : List TagCount -> List Category
sumCategories tags =
    let
        filterCat tc =
            Maybe.map (\cat -> Category cat tc.count) tc.tag.category

        withCats =
            List.filterMap filterCat tags

        sum cat mc =
            Maybe.map ((+) cat.count) mc
                |> Maybe.withDefault cat.count
                |> Just

        sumCounts cat dict =
            Dict.update cat.name (sum cat) dict

        cats =
            List.foldl sumCounts Dict.empty withCats
    in
    Dict.toList cats
        |> List.map (\( n, c ) -> Category n c)



--- Update


type Msg
    = ToggleTag String
    | ToggleCat String
    | ToggleExpandTags
    | ToggleExpandCats


type alias Selection =
    { includeTags : List TagCount
    , excludeTags : List TagCount
    , includeCats : List Category
    , excludeCats : List Category
    }


emptySelection : Selection
emptySelection =
    Selection [] [] [] []


update : Msg -> Model -> ( Model, Selection )
update msg model =
    case msg of
        ToggleTag id ->
            let
                next =
                    updateSelection id model.selectedTags

                model_ =
                    { model | selectedTags = next }
            in
            ( model_, getSelection model_ )

        ToggleCat name ->
            let
                next =
                    updateSelection name model.selectedCats

                model_ =
                    { model | selectedCats = next }
            in
            ( model_, getSelection model_ )

        ToggleExpandTags ->
            ( { model | expandedTags = not model.expandedTags }
            , getSelection model
            )

        ToggleExpandCats ->
            ( { model | expandedCats = not model.expandedCats }
            , getSelection model
            )


updateSelection : String -> Dict String Bool -> Dict String Bool
updateSelection id selected =
    let
        current =
            Dict.get id selected
    in
    case current of
        Nothing ->
            Dict.insert id True selected

        Just True ->
            Dict.insert id False selected

        Just False ->
            Dict.remove id selected


getSelection : Model -> Selection
getSelection model =
    let
        ( inclTags, exclTags ) =
            getSelection1 (\t -> t.tag.id) model.selectedTags model.all

        ( inclCats, exclCats ) =
            getSelection1 (\c -> c.name) model.selectedCats model.categories
    in
    Selection inclTags exclTags inclCats exclCats


getSelection1 : (a -> String) -> Dict String Bool -> List a -> ( List a, List a )
getSelection1 mkId selected items =
    let
        selectedOnly t =
            Dict.member (mkId t) selected

        isIncluded t =
            Dict.get (mkId t) selected
                |> Maybe.withDefault False
    in
    List.filter selectedOnly items
        |> List.partition isIncluded



--- View


type SelState
    = Include
    | Exclude
    | Deselect


tagState : Model -> String -> SelState
tagState model id =
    case Dict.get id model.selectedTags of
        Just True ->
            Include

        Just False ->
            Exclude

        Nothing ->
            Deselect


catState : Model -> String -> SelState
catState model name =
    case Dict.get name model.selectedCats of
        Just True ->
            Include

        Just False ->
            Exclude

        Nothing ->
            Deselect


view : UiSettings -> Model -> Html Msg
view settings model =
    div [ class "ui list" ]
        [ div [ class "item" ]
            [ I.tagIcon ""
            , div [ class "content" ]
                [ div [ class "header" ]
                    [ text "Tags"
                    ]
                , div [ class "ui relaxed list" ]
                    (List.map (viewTagItem settings model) model.all)
                ]
            ]
        , div [ class "item" ]
            [ I.tagsIcon ""
            , div [ class "content" ]
                [ div [ class "header" ]
                    [ text "Categories"
                    ]
                , div [ class "ui relaxed list" ]
                    (List.map (viewCategoryItem settings model) model.categories)
                ]
            ]
        ]


viewCategoryItem : UiSettings -> Model -> Category -> Html Msg
viewCategoryItem settings model cat =
    let
        state =
            catState model cat.name

        color =
            Data.UiSettings.catColorString settings cat.name

        icon =
            getIcon state color I.tagsIcon
    in
    a
        [ class "item"
        , href "#"
        , onClick (ToggleCat cat.name)
        ]
        [ icon
        , div [ class "content" ]
            [ div
                [ classList
                    [ ( "header", state == Include )
                    , ( "description", state /= Include )
                    ]
                ]
                [ text cat.name
                , div [ class "ui right floated circular label" ]
                    [ text (String.fromInt cat.count)
                    ]
                ]
            ]
        ]


viewTagItem : UiSettings -> Model -> TagCount -> Html Msg
viewTagItem settings model tag =
    let
        state =
            tagState model tag.tag.id

        color =
            Data.UiSettings.tagColorString tag.tag settings

        icon =
            getIcon state color I.tagIcon
    in
    a
        [ class "item"
        , href "#"
        , onClick (ToggleTag tag.tag.id)
        ]
        [ icon
        , div [ class "content" ]
            [ div
                [ classList
                    [ ( "header", state == Include )
                    , ( "description", state /= Include )
                    ]
                ]
                [ text tag.tag.name
                , div [ class "ui right floated circular label" ]
                    [ text (String.fromInt tag.count)
                    ]
                ]
            ]
        ]


getIcon : SelState -> String -> (String -> Html msg) -> Html msg
getIcon state color default =
    case state of
        Include ->
            i [ class ("check icon " ++ color) ] []

        Exclude ->
            i [ class ("minus icon " ++ color) ] []

        Deselect ->
            default color
