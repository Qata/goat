module Goat.Subscriptions exposing (subscriptions)

import Goat.Helpers exposing (toDrawingPosition)
import Goat.Model exposing (AnnotationState(..), Flags, Model, init)
import Goat.Ports as Ports
import Goat.Update exposing (Msg(..), update)
import Keyboard.Extra as Keyboard
import Mouse


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch <|
        case model.images of
            Nothing ->
                [ Ports.setImages SetImages ]

            Just images ->
                if not model.imageSelected then
                    []
                else
                    case model.annotationState of
                        DrawingAnnotation drawing ->
                            [ Mouse.moves (ContinueDrawing << toDrawingPosition)
                            , Sub.map KeyboardMsg Keyboard.subscriptions
                            ]

                        ResizingAnnotation index annotation start vertex ->
                            [ Mouse.moves (ResizeAnnotation index annotation vertex start << toDrawingPosition)
                            , Sub.map KeyboardMsg Keyboard.subscriptions
                            ]

                        MovingAnnotation index annotation start ->
                            [ Mouse.moves (MoveAnnotation index annotation start << toDrawingPosition) ]

                        _ ->
                            [ Sub.map KeyboardMsg Keyboard.subscriptions ]
