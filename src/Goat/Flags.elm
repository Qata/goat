module Goat.Flags exposing (Flags, decodeFlags)

import Json.Decode as Json
import Goat.Environment exposing (OperatingSystem(..), Platform(..))


type alias Flags =
    { os : OperatingSystem
    , platform : Platform
    }


isMacToOS isMac =
    if isMac then
        MacOS
    else
        Windows


isZendeskToPlatform inZendesk =
    if inZendesk then
        Zendesk
    else
        Web


decodeFlagsHelper =
    Json.map2 Flags
        (Json.map isMacToOS (Json.field "isMac" Json.bool))
        (Json.map isZendeskToPlatform (Json.field "inZendesk" Json.bool))


decodeFlags : Json.Value -> Result String Flags
decodeFlags =
    Json.decodeValue
        decodeFlagsHelper
