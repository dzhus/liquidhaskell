{-# LANGUAGE FlexibleContexts         #-}
module Language.Haskell.Liquid.Bare.Misc (
    makeSymbols

  , joinVar

  , mkVarExpr

  , MapTyVarST(..)
  , initMapSt
  , runMapTyVars
  , mapTyVars

  , symbolRTyVar
  , simpleSymbolVar

  , hasBoolResult
  ) where

import           Name
import           Prelude                               hiding (error)
import           TysWiredIn

import           Id
import           Type
import           TypeRep
import           Var

import           Control.Monad.Except                  (MonadError, throwError)
import           Control.Monad.State
import           Data.Maybe                            (isNothing)

import qualified Data.List                             as L

import           Language.Fixpoint.Misc                (sortNub)
import           Language.Fixpoint.Types               (Symbol, Expr(..), Reft(..), Reftable(..), mkEApp, emptySEnv, memberSEnv, symbol, syms, toReft)

import           Language.Haskell.Liquid.GHC.Misc
import           Language.Haskell.Liquid.Types.RefType
import           Language.Haskell.Liquid.Types
import           Language.Haskell.Liquid.Misc          (sortDiff)

import           Language.Haskell.Liquid.Bare.Env


-- TODO: This is where unsorted stuff is for now. Find proper places for what follows.

-- WTF does this function do?
makeSymbols :: (Functor t1, Functor t2, Foldable t, Foldable t1, Foldable t2, Reftable r,
                Reftable r1, Reftable r2, TyConable c, TyConable c1, TyConable c2, MonadState BareEnv m)
            => (Id -> Bool)
            -> [Id]
            -> [Symbol]
            -> t2 (a1, Located (RType c2 tv2 r2))
            -> t1 (a, Located (RType c1 tv1 r1))
            -> t (Located (RType c tv r))
            -> m [(Symbol, Var)]
makeSymbols f vs xs' xts yts ivs
  = do svs <- gets varEnv
       return $ L.nub ([ (x,v') | (x,v) <- svs, x `elem` xs, let (v',_,_) = joinVar vs (v,x,x)]
                       ++  [ (symbol v, v) | v <- vs, f v, isDataConId v, hasBasicArgs $ varType v ])
    where
      xs    = sortNub $ zs ++ zs' ++ zs''
      zs    = concatMap freeSymbols (snd <$> xts) `sortDiff` xs'
      zs'   = concatMap freeSymbols (snd <$> yts) `sortDiff` xs'
      zs''  = concatMap freeSymbols ivs           `sortDiff` xs'

      -- arguments should be basic so that autogenerated singleton types are well formed
      hasBasicArgs (ForAllTy _ t) = hasBasicArgs t
      hasBasicArgs (FunTy tx t)   = isBaseTy tx && hasBasicArgs t
      hasBasicArgs _              = True


freeSymbols :: (Reftable r, TyConable c) => Located (RType c tv r) -> [Symbol]
freeSymbols ty = sortNub $ concat $ efoldReft (\_ _ -> []) (const ()) f (const id) emptySEnv [] (val ty)
  where
    f γ _ r xs = let Reft (v, _) = toReft r in
                 [ x | x <- syms r, x /= v, not (x `memberSEnv` γ)] : xs

-------------------------------------------------------------------------------
-- Renaming Type Variables in Haskell Signatures ------------------------------
-------------------------------------------------------------------------------

data MapTyVarST = MTVST { vmap   :: [(Var, RTyVar)]
                        , errmsg :: Error
                        }

initMapSt :: Error -> MapTyVarST
initMapSt = MTVST []

-- TODO: Maybe don't expose this; instead, roll this in with mapTyVar and export a
--       single "clean" function as the API.
runMapTyVars :: StateT MapTyVarST (Either Error) () -> MapTyVarST -> Either Error MapTyVarST
runMapTyVars = execStateT

mapTyVars :: (PPrint r, Reftable r) => Type -> RRType r -> StateT MapTyVarST (Either Error) ()
mapTyVars τ (RAllT _ t)
  = mapTyVars τ t
mapTyVars (ForAllTy _ τ) t
  = mapTyVars τ t
mapTyVars (FunTy τ τ') (RFun _ t t' _)
   = mapTyVars τ t  >> mapTyVars τ' t'
mapTyVars (TyConApp _ τs) (RApp _ ts _ _)
   = zipWithM_ mapTyVars τs ts
mapTyVars (TyVarTy α) (RVar a _)
   = do s  <- get
        s' <- mapTyRVar α a s
        put s'
mapTyVars τ (RAllP _ t)
  = mapTyVars τ t
mapTyVars τ (RAllS _ t)
  = mapTyVars τ t
mapTyVars τ (RAllE _ _ t)
  = mapTyVars τ t
mapTyVars τ (RRTy _ _ _ t)
  = mapTyVars τ t
mapTyVars τ (REx _ _ t)
  = mapTyVars τ t
mapTyVars _ (RExprArg _)
  = return ()
mapTyVars (AppTy τ τ') (RAppTy t t' _)
  = do  mapTyVars τ t
        mapTyVars τ' t'
mapTyVars _ (RHole _)
  = return ()
mapTyVars _ _
  = throwError =<< errmsg <$> get

mapTyRVar :: MonadError Error m
          => Var -> RTyVar -> MapTyVarST -> m MapTyVarST
mapTyRVar α a s@(MTVST αas err)
  = case lookup α αas of
      Just a' | a == a'   -> return s
              | otherwise -> throwError err
      Nothing             -> return $ MTVST ((α,a):αas) err




mkVarExpr :: Id -> Expr
mkVarExpr v
  | isFunVar v = mkEApp (varFunSymbol v) []
  | otherwise  = EVar (symbol v)

varFunSymbol :: Id -> Located Symbol
varFunSymbol = dummyLoc . symbol . idDataCon

isFunVar :: Id -> Bool
isFunVar v   = isDataConId v && not (null αs) && isNothing tf
  where
    (αs, t)  = splitForAllTys $ varType v
    tf       = splitFunTy_maybe t

-- the Vars we lookup in GHC don't always have the same tyvars as the Vars
-- we're given, so return the original var when possible.
-- see tests/pos/ResolvePred.hs for an example
joinVar :: [Var] -> (Var, s, t) -> (Var, s, t)
joinVar vs (v,s,t) = case L.find ((== showPpr v) . showPpr) vs of
                       Just v' -> (v',s,t)
                       Nothing -> (v,s,t)


simpleSymbolVar :: Var -> Symbol
simpleSymbolVar  = dropModuleNames . symbol . showPpr . getName

hasBoolResult :: Type -> Bool
hasBoolResult (ForAllTy _ t) = hasBoolResult t
hasBoolResult (FunTy _ t)    | eqType boolTy t = True
hasBoolResult (FunTy _ t)    = hasBoolResult t
hasBoolResult _              = False
