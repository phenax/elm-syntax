module Elm.Syntax.DeconstructPattern exposing
    ( QualifiedNameRef
    , moduleNames
    , encode, decoder
    , DeconstructPattern(..)
    )

{-|


# Pattern Syntax

This syntax represents the patterns.
For example:

    Just x as someMaybe
    {name, age}


# Types

@docs Pattern, QualifiedNameRef


## Functions

@docs moduleNames


## Serialization

@docs encode, decoder

-}

import Elm.Json.Util exposing (decodeTyped, encodeTyped)
import Elm.Syntax.ModuleName as ModuleName exposing (ModuleName)
import Elm.Syntax.Node as Node exposing (Node(..))
import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE exposing (Value)


{-| Custom type for all patterns such as:

  - `AllPattern`: `_`
  - `UnitPattern`: `()`
  - `CharPattern`: `'c'`
  - `StringPattern`: `"hello"`
  - `IntPattern`: `42`
  - `HexPattern`: `0x11`
  - `FloatPattern`: `42.0`
  - `TuplePattern`: `(a, b)`
  - `RecordPattern`: `{name, age}`
  - `UnConsPattern`: `x :: xs`
  - `ListPattern`: `[ x, y ]`
  - `VarPattern`: `x`
  - `NamedPattern`: `Just _`
  - `AsPattern`: `_ as x`
  - `ParenthesizedPattern`: `( _ )`

-}
type DeconstructPattern
    = AllPattern_
    | UnitPattern_
    | TuplePattern_ (List (Node DeconstructPattern))
    | RecordPattern_ (List (Node String))
    | VarPattern_ String
    | NamedPattern_ QualifiedNameRef (List (Node DeconstructPattern))
    | AsPattern_ (Node DeconstructPattern) (Node String)
    | ParenthesizedPattern_ (Node DeconstructPattern)


{-| Qualified name reference such as `Maybe.Just`.
-}
type alias QualifiedNameRef =
    { moduleName : List String
    , name : String
    }


{-| Get all the modules names that are used in the pattern (and its nested patterns).
Use this to collect qualified patterns, such as `Maybe.Just x`.
-}
moduleNames : DeconstructPattern -> List ModuleName
moduleNames p =
    let
        recur =
            Node.value >> moduleNames
    in
    case p of
        TuplePattern_ xs ->
            List.concatMap recur xs

        RecordPattern_ _ ->
            []

        NamedPattern_ qualifiedNameRef subPatterns ->
            qualifiedNameRef.moduleName :: List.concatMap recur subPatterns

        AsPattern_ inner _ ->
            recur inner

        ParenthesizedPattern_ inner ->
            recur inner

        _ ->
            []



-- Serialization


{-| Encode a `Pattern` syntax element to JSON.
-}
encode : DeconstructPattern -> Value
encode pattern =
    case pattern of
        AllPattern_ ->
            encodeTyped "all" (JE.object [])

        UnitPattern_ ->
            encodeTyped "unit" (JE.object [])

        TuplePattern_ patterns ->
            encodeTyped "tuple"
                (JE.object
                    [ ( "value", JE.list (Node.encode encode) patterns )
                    ]
                )

        RecordPattern_ pointers ->
            encodeTyped "record"
                (JE.object
                    [ ( "value", JE.list (Node.encode JE.string) pointers )
                    ]
                )

        VarPattern_ name ->
            encodeTyped "var"
                (JE.object
                    [ ( "value", JE.string name )
                    ]
                )

        NamedPattern_ qualifiedNameRef patterns ->
            encodeTyped "named" <|
                JE.object
                    [ ( "qualified"
                      , JE.object
                            [ ( "moduleName", ModuleName.encode qualifiedNameRef.moduleName )
                            , ( "name", JE.string qualifiedNameRef.name )
                            ]
                      )
                    , ( "patterns", JE.list (Node.encode encode) patterns )
                    ]

        AsPattern_ destructured name ->
            encodeTyped "as" <|
                JE.object
                    [ ( "name", Node.encode JE.string name )
                    , ( "pattern", Node.encode encode destructured )
                    ]

        ParenthesizedPattern_ p1 ->
            encodeTyped "parentisized"
                (JE.object
                    [ ( "value", Node.encode encode p1 )
                    ]
                )


{-| JSON decoder for a `Pattern` syntax element.
-}
decoder : Decoder DeconstructPattern
decoder =
    JD.lazy
        (\() ->
            decodeTyped
                [ ( "all", JD.succeed AllPattern_ )
                , ( "unit", JD.succeed UnitPattern_ )
                , ( "tuple", JD.field "value" (JD.list (Node.decoder decoder)) |> JD.map TuplePattern_ )
                , ( "record", JD.field "value" (JD.list (Node.decoder JD.string)) |> JD.map RecordPattern_ )
                , ( "var", JD.field "value" JD.string |> JD.map VarPattern_ )
                , ( "named", JD.map2 NamedPattern_ (JD.field "qualified" decodeQualifiedNameRef) (JD.field "patterns" (JD.list (Node.decoder decoder))) )
                , ( "as", JD.map2 AsPattern_ (JD.field "pattern" (Node.decoder decoder)) (JD.field "name" (Node.decoder JD.string)) )
                , ( "parentisized", JD.map ParenthesizedPattern_ (JD.field "value" (Node.decoder decoder)) )
                ]
        )


decodeQualifiedNameRef : Decoder QualifiedNameRef
decodeQualifiedNameRef =
    JD.map2 QualifiedNameRef
        (JD.field "moduleName" ModuleName.decoder)
        (JD.field "name" JD.string)


decodeChar : Decoder Char
decodeChar =
    JD.string
        |> JD.andThen
            (\s ->
                case String.uncons s of
                    Just ( c, _ ) ->
                        JD.succeed c

                    Nothing ->
                        JD.fail "Not a char"
            )
