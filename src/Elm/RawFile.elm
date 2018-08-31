module Elm.RawFile exposing
    ( RawFile
    , moduleName, imports
    , encode, decoder
    )

{-|


# Elm.RawFile

@docs RawFile

@docs moduleName, imports


## Serialization

@docs encode, decoder

-}

import Elm.Internal.RawFile as Internal exposing (RawFile(..))
import Elm.Syntax.File as File
import Elm.Syntax.Import exposing (Import)
import Elm.Syntax.Module as Module
import Elm.Syntax.ModuleName exposing (ModuleName)
import Elm.Syntax.Node as Node
import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE exposing (Value)


{-| A Raw file
-}
type alias RawFile =
    Internal.RawFile


{-| Retrieve the module name for a raw file
-}
moduleName : RawFile -> ModuleName
moduleName (Internal.Raw file) =
    Module.moduleName <| Node.value file.moduleDefinition


{-| Retrieve the imports for a raw file
-}
imports : RawFile -> List Import
imports (Internal.Raw file) =
    List.map Node.value file.imports


{-| Encode a file to a value
-}
encode : RawFile -> Value
encode (Raw file) =
    File.encode file


decoder : Decoder RawFile
decoder =
    JD.map Raw File.decoder
