module Even where

data Peano
  = Z
  | S Peano

data Even where
  EZ  :: Even
  ESS :: Peano -> Even -> Even

{-@ data Even :: Peano -> Prop where
      EZ  :: {v:Even | prop v = Even Z}
      ESS :: n:Peano -> {v:Even | prop v = Even n} -> {v:Even | prop v = Even (S (S n)) }
  @-}

{-

1. DataProp
    - parser
    - spec

2. DataProp -> [DataDecl]


ctors

  EZ  :: {v:Even | prop v = Even Z}
  ESS :: n:Peano -> {v:Even | prop v = Even n} -> {v:Even | prop v = Even (S (S n)) }

datatypes

  datatype Even#Prop = [
    | Even { x0 : Peano }
  ]

  datatype Even = [
    | EZ  { }
    | ESS { x0 : Peano, x1 : Even }
  ]

 -}


{-@ test :: n:Peano -> {v:Even | prop v = Even (S (S n))} -> {v:Even | prop v = Even n} @-}
test :: Peano -> Even -> Even
test n p@EZ        = p      -- contra "..."
test n p@(ESS m q) = q      -- G := p : {prop p  = Even (S (S n)) /\ prop p = Even (S (S m))}
                            --        ; q : {prop q = Even m}
                            --        ==> n = m
                            --        ==> prop q = Even n