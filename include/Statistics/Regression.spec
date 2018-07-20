module spec Statistics.Regression where

import Data.Vector.Unboxed

olsRegress
    :: ps:[Data.Vector.Unboxed.Vector Double]
    -> r:(Data.Vector.Unboxed.Vector Double)
    -> {reg:(Data.Vector.Unboxed.Vector Double, Double) | vlen (fst reg) = len ps + 1}
