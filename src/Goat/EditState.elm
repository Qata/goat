module Goat.EditState exposing (EditState, Config, MoveInfo, ResizingInfo, Vertex(..), initialState, startDrawing, continueDrawing, finishDrawing, startMoving, continueMoving, finishMoving, startResizing, continueResizing, finishResizing, selectAnnotation, startEditingText, finishEditingText, selectedId, updateSelectedAttributes, subscriptions, getDrawingAttributes, getSelectState, toDrawingAreaCursor, whenNotSelecting, whenDrawing, whenSelecting, whenMoving, whenResizing, whenEditingText)

import Color exposing (Color)
import Goat.AnnotationAttributes as Annotation exposing (AnnotationAttributes, SelectState, StrokeStyle, SelectState(..))
import Keyboard.Extra as Keyboard exposing (KeyChange)
import Mouse exposing (Position)


{-| Vertices are classified by their relationship to the `start` and `end`
mouse positions that created the annotation.

e.g: (assume a top-left to bottom-right draw)

Start StartPlusX
+----------+
|**********|
|**********|
|**********|
|**********|
|**********|
+----------+
StartPlusY End

-}
type Vertex
    = Start
    | End
    | StartPlusX
    | StartPlusY


type alias Config msg =
    { drawToMsg : Position -> msg
    , resizeToMsg : Position -> msg
    , moveToMsg : Position -> msg
    , keyboardToMsg : Keyboard.Msg -> msg
    }


type alias DrawingInfo =
    { start : Position
    , curPos : Position
    , freeDrawPositions : List Position
    }


type alias SelectingInfo =
    { id : Int
    , attributes : AnnotationAttributes
    }


type alias MoveInfo =
    { id : Int
    , start : Position
    , translate : ( Int, Int )
    , attributes : AnnotationAttributes
    }


type alias ResizingInfo =
    { id : Int
    , start : Position
    , curPos : Position
    , vertex : Vertex
    , originalCoords : ( Position, Position )
    , attributes : AnnotationAttributes
    }


type alias EditingTextInfo =
    { id : Int
    , attributes : AnnotationAttributes
    }


{-| The finite state machine for annotating.
See <https://github.com/thebritican/goat/wiki/The-Annotation-Editor's-Finite-State-Machine>
-}
type EditState
    = ReadyToDraw
    | DrawingAnnotation DrawingInfo
    | SelectedAnnotation SelectingInfo
    | MovingAnnotation MoveInfo
    | ResizingAnnotation ResizingInfo
    | EditingATextBox EditingTextInfo


initialState : EditState
initialState =
    ReadyToDraw


editStateAttributes :
    { strokeColor : Color
    , fill : Maybe Color
    , strokeStyle : StrokeStyle
    , fontSize : Int
    }
    -> EditState
    -> AnnotationAttributes
editStateAttributes { strokeColor, fill, strokeStyle, fontSize } editState =
    case editState of
        SelectedAnnotation { attributes } ->
            attributes

        MovingAnnotation { attributes } ->
            attributes

        ResizingAnnotation { attributes } ->
            attributes

        EditingATextBox { attributes } ->
            attributes

        _ ->
            AnnotationAttributes strokeColor fill strokeStyle fontSize


startDrawing : Position -> EditState -> EditState
startDrawing start editState =
    DrawingAnnotation (DrawingInfo start start [])


continueDrawing : Position -> Bool -> EditState -> EditState
continueDrawing pos isFreeHand editState =
    case editState of
        DrawingAnnotation { start, freeDrawPositions } ->
            if isFreeHand then
                DrawingAnnotation
                    (DrawingInfo start pos <|
                        case freeDrawPositions of
                            [] ->
                                [ pos ]

                            lastPos :: rest ->
                                if (abs (lastPos.x - pos.x)) < 10 && (abs (lastPos.y - pos.y)) < 10 then
                                    freeDrawPositions
                                else
                                    pos :: freeDrawPositions
                    )
            else
                DrawingAnnotation (DrawingInfo start pos [])

        _ ->
            editState


finishDrawing editState =
    case editState of
        DrawingAnnotation { start, freeDrawPositions } ->
            Just ( ReadyToDraw, start, freeDrawPositions )

        _ ->
            Nothing


selectAnnotation id annotationAttrs editState =
    SelectedAnnotation (SelectingInfo id annotationAttrs)


startMoving start editState =
    case editState of
        SelectedAnnotation { id, attributes } ->
            MovingAnnotation (MoveInfo id start ( 0, 0 ) attributes)

        _ ->
            editState


continueMoving newPos editState =
    case editState of
        MovingAnnotation moveInfo ->
            MovingAnnotation { moveInfo | translate = ( newPos.x - moveInfo.start.x, newPos.y - moveInfo.start.y ) }

        _ ->
            editState


finishMoving editState =
    case editState of
        MovingAnnotation { id, translate } ->
            Just ( ReadyToDraw, id, translate )

        _ ->
            Nothing


startResizing start vertex annotation editState =
    case editState of
        SelectedAnnotation { id, attributes } ->
            ResizingAnnotation (ResizingInfo id start start vertex (Annotation.positions annotation) attributes)

        _ ->
            editState


continueResizing curPos editState =
    case editState of
        ResizingAnnotation resizingData ->
            Just
                ( ResizingAnnotation { resizingData | curPos = curPos }
                , resizingData
                )

        _ ->
            Nothing


finishResizing editState =
    case editState of
        ResizingAnnotation { id, attributes } ->
            SelectedAnnotation (SelectingInfo id attributes)

        _ ->
            editState


startEditingText id attrs editState =
    EditingATextBox (EditingTextInfo id attrs)


finishEditingText editState =
    case editState of
        EditingATextBox _ ->
            ReadyToDraw

        _ ->
            editState


updateSelectedAttributes updateAttrs editState =
    case editState of
        SelectedAnnotation selectingInfo ->
            SelectedAnnotation { selectingInfo | attributes = (updateAttrs selectingInfo.attributes) }

        EditingATextBox editingInfo ->
            EditingATextBox { editingInfo | attributes = (updateAttrs editingInfo.attributes) }

        _ ->
            editState


subscriptions : Config msg -> EditState -> Sub msg
subscriptions config editState =
    Sub.batch <|
        case editState of
            DrawingAnnotation _ ->
                [ Mouse.moves config.drawToMsg
                , Sub.map config.keyboardToMsg Keyboard.subscriptions
                ]

            ResizingAnnotation _ ->
                [ Mouse.moves config.resizeToMsg
                , Sub.map config.keyboardToMsg Keyboard.subscriptions
                ]

            MovingAnnotation _ ->
                [ Mouse.moves config.moveToMsg ]

            _ ->
                [ Sub.map config.keyboardToMsg Keyboard.subscriptions ]


selectedId editState =
    case editState of
        SelectedAnnotation { id } ->
            Just id

        EditingATextBox { id } ->
            Just id

        _ ->
            Nothing



-- EditingATextBox index _ ->
--     { model
--         | edits = UndoList.mapPresent (mapAtIndex index fn) model.edits
--     }


toDrawingAreaCursor : EditState -> String
toDrawingAreaCursor editState =
    case editState of
        ReadyToDraw ->
            "crosshair"

        DrawingAnnotation _ ->
            "crosshair"

        MovingAnnotation _ ->
            "move"

        ResizingAnnotation _ ->
            "nesw-resize"

        EditingATextBox _ ->
            "default"

        _ ->
            "crosshair"


getSelectState : Int -> Bool -> EditState -> SelectState
getSelectState candidateId isFreeHand editState =
    case editState of
        SelectedAnnotation { id } ->
            if id == candidateId then
                if isFreeHand then
                    Selected
                else
                    SelectedWithVertices
            else
                NotSelected

        MovingAnnotation { id } ->
            if id == candidateId then
                if isFreeHand then
                    Selected
                else
                    SelectedWithVertices
            else
                NotSelected

        ResizingAnnotation { id } ->
            if id == candidateId then
                if isFreeHand then
                    Selected
                else
                    SelectedWithVertices
            else
                NotSelected

        EditingATextBox { id } ->
            if id == candidateId then
                Selected
            else
                NotSelected

        _ ->
            NotSelected



-- map : Config msg a -> EditState -> a -> a
-- map config editState someModel =
--     case editState of
--         ReadyToDraw ->
--             config.whenNotSelecting someModel
--
--         DrawingAnnotation _ _ _ ->
--             config.whenDrawing someModel
--
--         SelectedAnnotation id _ ->
--             config.whenSelecting id someModel
--
--         MovingAnnotation moveInfo ->
--             config.whenMoving moveInfo someModel
--
--         ResizingAnnotation _ _ ->
--             config.whenResizing someModel
--
--         EditingATextBox id _ ->
--             config.whenEditingText id someModel


whenNotSelecting : a -> EditState -> a -> a
whenNotSelecting notSelectingVal editState a =
    case editState of
        ReadyToDraw ->
            notSelectingVal

        _ ->
            a


whenDrawing : (DrawingInfo -> a) -> EditState -> a -> a
whenDrawing f editState a =
    case editState of
        DrawingAnnotation drawingInfo ->
            f drawingInfo

        _ ->
            a


whenSelecting : (Int -> a) -> EditState -> a -> a
whenSelecting f editState a =
    case editState of
        SelectedAnnotation { id } ->
            f id

        _ ->
            a


whenMoving : (MoveInfo -> a) -> EditState -> a -> a
whenMoving f editState a =
    case editState of
        MovingAnnotation moveInfo ->
            f moveInfo

        _ ->
            a


whenResizing : (ResizingInfo -> a) -> EditState -> a -> a
whenResizing f editState a =
    case editState of
        ResizingAnnotation resizingInfo ->
            f resizingInfo

        _ ->
            a


whenEditingText : (Int -> a) -> EditState -> a -> a
whenEditingText f editState a =
    case editState of
        EditingATextBox { id } ->
            f id

        _ ->
            a


getDrawingAttributes editState =
    case editState of
        DrawingAnnotation { start, curPos, freeDrawPositions } ->
            Just ( start, curPos, freeDrawPositions )

        _ ->
            Nothing
