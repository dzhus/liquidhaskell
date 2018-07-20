module spec Data.Vector.Unboxed where

import GHC.Base

data variance Data.Vector.Unboxed.Vector covariant


measure vlen    :: forall a. (Data.Vector.Unboxed.Vector a) -> Int

invariant       {v: Data.Vector.Unboxed.Vector a | 0 <= vlen v }

!           :: forall a. x:(Data.Vector.Unboxed.Vector a) -> vec:{v:Nat | v < vlen x } -> a

unsafeIndex :: forall a. x:(Data.Vector.Unboxed.Vector a) -> vec:{v:Nat | v < vlen x } -> a

fromList  :: forall a. x:[a] -> {v: Data.Vector.Unboxed.Vector a  | vlen v = len x }

length    :: forall a. x:(Data.Vector.Unboxed.Vector a) -> {v : Nat | v = vlen x }

replicate :: n:Nat -> a -> {v:Data.Vector.Unboxed.Vector a | vlen v = n}

generate :: n:Nat -> (n:Nat -> a) -> {v:Data.Vector.Unboxed.Vector a | vlen v = n}

imap :: (Nat -> a -> b) -> x:(Data.Vector.Unboxed.Vector a) -> {y:Data.Vector.Unboxed.Vector b | vlen y = vlen x }

map :: (a -> b) -> x:(Data.Vector.Unboxed.Vector a) -> {y:Data.Vector.Unboxed.Vector b | vlen y = vlen x }
