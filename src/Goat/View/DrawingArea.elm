module Goat.View.DrawingArea exposing (viewDrawingArea, viewAnnotationMenu)

import Array.Hamt as Array exposing (Array)
import Goat.Annotation exposing (Annotation(..), AnnotationAttributes)
import Goat.EditState as EditState exposing (EditState)
import Goat.Flags exposing (Image)
import Goat.Model exposing (Drawing(..))
import Goat.Update exposing (Msg(..), autoExpandConfig)
import Goat.Utils exposing (getFirstSpotlightIndex, isSpotlightDrawing, toDrawingPosition, toPosition)
import Goat.View.DrawingArea.Annotation as Annotation exposing (viewAnnotation)
import Goat.View.DrawingArea.Definitions as Definitions
import Goat.View.EventUtils exposing (defaultPrevented, stopPropagation, onMouseDown, onMouseUp)
import Goat.View.Utils exposing (toPx)
import Html exposing (Attribute, Html, button, div, h2, h3, img, li, p, text, ul)
import Html.Attributes exposing (attribute, class, classList, disabled, id, src, style)
import Html.Events exposing (onClick, onMouseEnter, onWithOptions)
import Json.Decode as Json
import Mouse exposing (Position)
import Rocket exposing ((=>))
import SingleTouch as ST
import Svg exposing (Svg, circle, defs, foreignObject, marker, rect, svg)
import Svg.Attributes as Attr
import Svg.Lazy
import Touch as T


viewPixelatedImage : Image -> Svg Msg
viewPixelatedImage { width, height, url } =
    Svg.image
        [ Attr.width (toString (round width))
        , Attr.height (toString (round height))
        , Attr.xlinkHref url
        , Attr.filter "url(#pixelate)"
        ]
        []


viewImage : Image -> Svg Msg
viewImage { url, width, height } =
    Svg.image
        [ Attr.class "image-to-annotate"
        , Attr.width (toString (round width))
        , Attr.height (toString (round height))
        , Attr.xlinkHref url
        , Attr.mask "url(#pixelateMask)"
        ]
        []


drawingStateEvents : EditState -> List (Attribute Msg)
drawingStateEvents editState =
    []
        |> EditState.whenNotSelecting drawingAreaAttrsWhenNotSelecting editState
        |> EditState.whenDrawing drawingAreaAttrsWhenDrawing editState
        |> EditState.whenSelecting drawingAreaAttrsWhenSelecting editState
        |> EditState.whenMoving drawingAreaAttrsWhenMoving editState
        |> EditState.whenResizing drawingAreaAttrsWhenResizing editState
        |> EditState.whenEditingText (drawingAreaAttrsWhenEditingText << .id) editState


drawingAreaAttrsWhenNotSelecting : List (Svg.Attribute Msg)
drawingAreaAttrsWhenNotSelecting =
    [ onMouseDown <| Json.map (StartDrawing << toDrawingPosition) Mouse.position
    , ST.onSingleTouch T.TouchStart T.preventAndStop <| (StartDrawing << toDrawingPosition << toPosition)
    , onWithOptions "contextmenu" defaultPrevented (Json.map ToggleAnnotationMenu Mouse.position)
    ]


drawingAreaAttrsWhenDrawing : a -> List (Attribute Msg)
drawingAreaAttrsWhenDrawing _ =
    [ onMouseUp (Json.map (FinishDrawing << toDrawingPosition) Mouse.position)
    , ST.onSingleTouch T.TouchEnd T.preventAndStop (FinishDrawing << toDrawingPosition << toPosition)
    , ST.onSingleTouch T.TouchMove T.preventAndStop (ContinueDrawing << toDrawingPosition << toPosition)
    , onWithOptions "contextmenu" defaultPrevented (Json.map ToggleAnnotationMenu Mouse.position)
    ]


drawingAreaAttrsWhenSelecting : a -> List (Attribute Msg)
drawingAreaAttrsWhenSelecting _ =
    [ onMouseDown <| Json.map (StartDrawing << toDrawingPosition) Mouse.position
    , ST.onSingleTouch T.TouchStart T.preventAndStop <| (StartDrawing << toDrawingPosition << toPosition)
    ]


drawingAreaAttrsWhenMoving : a -> List (Attribute Msg)
drawingAreaAttrsWhenMoving _ =
    [ onMouseUp <| Json.map (FinishMovingAnnotation << toDrawingPosition) Mouse.position
    , ST.onSingleTouch T.TouchMove T.preventAndStop (MoveAnnotation << toDrawingPosition << toPosition)
    , ST.onSingleTouch T.TouchEnd T.preventAndStop (FinishMovingAnnotation << toDrawingPosition << toPosition)
    , onWithOptions "contextmenu" defaultPrevented (Json.map ToggleAnnotationMenu Mouse.position)
    ]


drawingAreaAttrsWhenResizing : a -> List (Attribute Msg)
drawingAreaAttrsWhenResizing _ =
    [ onMouseUp <| Json.map (FinishResizingAnnotation << toDrawingPosition) Mouse.position
    , ST.onSingleTouch T.TouchMove T.preventAndStop (ResizeAnnotation << toDrawingPosition << toPosition)
    , ST.onSingleTouch T.TouchEnd T.preventAndStop (FinishResizingAnnotation << toDrawingPosition << toPosition)
    , onWithOptions "contextmenu" defaultPrevented (Json.map ToggleAnnotationMenu Mouse.position)
    ]


drawingAreaAttrsWhenEditingText : Int -> List (Attribute Msg)
drawingAreaAttrsWhenEditingText index =
    [ Html.Events.onMouseDown <| FinishEditingText index
    , ST.onSingleTouch T.TouchStart T.preventAndStop (\_ -> FinishEditingText index)
    , onWithOptions "contextmenu" defaultPrevented (Json.map ToggleAnnotationMenu Mouse.position)
    ]


toDrawingAreaCursor : EditState -> String
toDrawingAreaCursor editState =
    "crosshair"
        |> EditState.whenEditingText (\_ -> "default") editState


canvasAttributes : Drawing -> EditState -> List (Svg.Attribute Msg)
canvasAttributes drawing editState =
    [ id "canvas"
    , class "image-edit"
    , style [ "cursor" => toDrawingAreaCursor editState ]
    , Html.Events.onMouseDown CloseDropdown
    , Html.Attributes.contextmenu "annotation-menu"
    ]
        ++ drawingStateEvents editState


getAnnotations : Image -> Array Annotation -> List (Svg Msg) -> List (Svg Msg) -> Bool -> List (Svg Msg)
getAnnotations image annotations spotlights nonSpotlights isDrawingSpotlight =
    let
        firstSpotlightIndex =
            getFirstSpotlightIndex annotations
    in
        if isDrawingSpotlight && List.isEmpty spotlights then
            nonSpotlights ++ [ viewMask image.width image.height ]
        else if List.isEmpty spotlights then
            nonSpotlights
        else
            List.take firstSpotlightIndex nonSpotlights
                ++ (viewMask image.width image.height
                        :: List.drop firstSpotlightIndex nonSpotlights
                   )


viewDrawingAndAnnotations :
    Image
    -> (List (Svg Msg) -> List (Svg Msg) -> List (Svg Msg))
    -> List (Svg Msg)
    -> List (Svg Msg)
    -> List (Svg Msg)
    -> (Bool -> Svg Msg)
    -> Drawing
    -> List (Svg Msg)
viewDrawingAndAnnotations image definitions spotlights pixelates annotations toDrawing drawing =
    let
        nonSpotlightDrawingAndAnnotations =
            definitions spotlights pixelates ++ (Svg.Lazy.lazy viewPixelatedImage image :: viewImage image :: annotations) ++ [ toDrawing False ]

        spotlightDrawingAndAnnotations =
            definitions (spotlights ++ [ toDrawing True ]) pixelates ++ (Svg.Lazy.lazy viewPixelatedImage image :: Svg.Lazy.lazy viewImage image :: annotations) ++ [ toDrawing False ]
    in
        case drawing of
            DrawSpotlight _ ->
                spotlightDrawingAndAnnotations

            _ ->
                nonSpotlightDrawingAndAnnotations


viewDrawingArea : Annotation.DrawingModifiers -> Array Annotation -> AnnotationAttributes -> Image -> Html Msg
viewDrawingArea ({ drawing, constrain, editState } as drawingModifiers) annotations annotationAttrs image =
    let
        toDrawing =
            Annotation.viewDrawing drawingModifiers annotationAttrs editState

        spotlights =
            Definitions.viewSpotlights editState annotations

        ( pixelates, svgAnnotations ) =
            Tuple.mapFirst (Definitions.viewPixelates editState) <|
                EditState.whenDrawing
                    (\{ start, curPos } ->
                        case drawing of
                            DrawPixelate ->
                                ( Array.push (Pixelate start curPos) annotations
                                , getAnnotations image annotations spotlights nonSpotlights (isSpotlightDrawing drawing)
                                )

                            _ ->
                                ( annotations, getAnnotations image annotations spotlights nonSpotlights (isSpotlightDrawing drawing) )
                    )
                    editState
                    ( annotations, getAnnotations image annotations spotlights nonSpotlights False )

        nonSpotlights =
            Definitions.viewNonSpotlightAnnotations editState annotations

        definitions =
            Definitions.viewDefinitions image.width image.height
    in
        div
            (canvasAttributes drawing editState)
            [ svg
                [ Attr.id "drawing"
                , Attr.class "drawing"
                , Attr.width (toString (round image.width))
                , Attr.height (toString (round image.height))
                , attribute "xmlns" "http://www.w3.org/2000/svg"
                ]
                (viewDrawingAndAnnotations image definitions spotlights pixelates svgAnnotations toDrawing drawing)
            ]


viewMask : Float -> Float -> Svg msg
viewMask width height =
    rect
        [ Attr.x "0"
        , Attr.y "0"
        , Attr.height <| toString height
        , Attr.width <| toString width
        , Attr.mask "url(#Mask)"
        , Attr.style "pointer-events: none;"
        ]
        []


viewAnnotationMenu : Position -> Maybe Int -> Html Msg
viewAnnotationMenu pos selectedIndex =
    div
        [ id "annotation-menu"
        , class "annotation-menu"
        , style
            [ ( "top", toPx pos.y )
            , ( "left", toPx pos.x )
            ]
        ]
        [ ul [ class "annotation-menu__list" ]
            (case selectedIndex of
                Just index ->
                    [ viewAnnotationMenuItem (BringAnnotationToFront index) "Bring to Front"
                    , viewAnnotationMenuItem (SendAnnotationToBack index) "Send to Back"
                    ]

                Nothing ->
                    [ viewDisabledAnnotationMenuItem "Bring to Front"
                    , viewDisabledAnnotationMenuItem "Send to Back"
                    ]
            )
        ]


viewDisabledAnnotationMenuItem : String -> Html Msg
viewDisabledAnnotationMenuItem buttonText =
    li [ class "annotation-menu__item" ]
        [ button
            [ class "annotation-menu__button"
            , disabled True
            ]
            [ text buttonText ]
        ]


viewAnnotationMenuItem : Msg -> String -> Html Msg
viewAnnotationMenuItem msg buttonText =
    li [ class "annotation-menu__item" ]
        [ button
            [ class "annotation-menu__button"
            , onClick msg
            ]
            [ text buttonText ]
        ]
