module spec Statistics.Sample.Histogram where

import Data.Vector.Generic

histogram
    :: bins:Nat
    -> {s:(v Double) | vlen s > 0}
    -> {res:(v1 Double, v1 b) | vlen (fst res) = vlen s && vlen (snd res) = vlen s}
