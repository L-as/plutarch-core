{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE UndecidableSuperClasses #-}

module Plutarch.Core (
  PDSL (..),
  PDSLKind (..),
  Term (..),
  unTerm,
  PConcrete,
  IsPType (..),
  PConstructable (..),
  PConstructable' (..),
  PAp (..),
  PEmbeds (..),
  Compile,
  CompileAp,
) where

import Data.Functor.Compose (Compose)
import Data.Kind (Constraint, Type)
import Data.Proxy (Proxy (Proxy))
import GHC.Records (HasField (getField))
import GHC.Stack (HasCallStack)
import GHC.TypeLits (Symbol)
import Plutarch.PType (
  PGeneric,
  PHs,
  PHs',
  PPType,
  PType,
  PTypeF,
  pattern MkPTypeF,
 )
import Plutarch.Reduce (NoReduce)
import Plutarch.Internal.CoerceTo (CoerceTo)
import Plutarch.Repr (PRepr, PReprIsPType, PReprSort, prIsPType, PIsRepr, PReprC, prto, prfrom)

newtype PDSLKind = PDSLKind (PType -> Type)

type family UnPDSLKind (edsl :: PDSLKind) :: PType -> Type where
  UnPDSLKind ( 'PDSLKind edsl) = edsl

type NoTypeInfo :: forall k. PHs k -> Constraint
class NoTypeInfo a
instance NoTypeInfo a

class Monad (PEffect edsl) => PDSL (edsl :: PDSLKind) where
  data PEffect edsl :: Type -> Type
  type IsPType' edsl :: forall (a :: PType). PHs a -> Constraint
  type IsPType' _ = NoTypeInfo

type role Term nominal nominal
newtype Term (edsl :: PDSLKind) (a :: PType) where
  Term :: UnPDSLKind edsl (PRepr a) -> Term edsl a

unTerm :: Term edsl a -> UnPDSLKind edsl (PRepr a)
unTerm (Term t) = t

type ClosedTerm (c :: PDSLKind -> Constraint) (a :: PType) = forall edsl. c edsl => Term edsl a

type IsPType :: PDSLKind -> forall (a :: PType). PHs a -> Constraint
class PDSL edsl => IsPType edsl (x :: PHs a) where
  isPType ::
    forall y.
    Proxy edsl ->
    Proxy x ->
    (forall a' (x' :: PHs a'). IsPType' edsl x' => Proxy x' -> y) ->
    y
instance (
  PDSL edsl,
  PReprC (PReprSort a) a, PIsRepr (PReprSort a), PReprIsPType (PReprSort a) a edsl x) => IsPType edsl (x :: PHs a) where
  isPType edsl x f = prIsPType edsl x (f (Proxy @(PRepr x)))

type H1 :: PDSLKind -> forall (a :: Type) -> a -> Constraint
type family H1 (edsl :: PDSLKind) (a :: Type) (x :: a) :: Constraint where
  H1 edsl PType x = IsPType edsl x
  forall (edsl :: PDSLKind) (a :: PType) (_ef :: PTypeF) (x :: a _ef).
    H1 edsl (a _ef) x =
      IsPType edsl (CoerceTo (PHs a) x)

type H2 :: PDSLKind -> forall (a :: Type). a -> Constraint
class H1 edsl a x => H2 edsl (x :: a)
instance H1 edsl a x => H2 edsl (x :: a)

type family Helper (edsl :: PDSLKind) :: PTypeF where
  Helper edsl = MkPTypeF (H2 edsl) (Compose NoReduce (Term edsl))

type PConcrete :: PDSLKind -> PType -> Type
type PConcrete edsl a = a (Helper edsl)

class (PDSL edsl, IsPType' edsl a) => PConstructable' edsl (a :: PType) where
  pconImpl :: HasCallStack => PConcrete edsl a -> UnPDSLKind edsl a
  pmatchImpl :: forall b. (HasCallStack, IsPType edsl b) => UnPDSLKind edsl a -> (PConcrete edsl a -> Term edsl b) -> Term edsl b
  pcaseImpl :: forall b. (HasCallStack, IsPType edsl b) => UnPDSLKind edsl a -> (PConcrete edsl a -> PEffect edsl (Term edsl b)) -> PEffect edsl (Term edsl b)

-- | The crux of what an eDSL is.
class IsPType edsl a => PConstructable edsl (a :: PType) where
  pcon :: HasCallStack => PConcrete edsl a -> Term edsl a
  pmatch ::
    forall b.
    (HasCallStack, IsPType edsl b) =>
    Term edsl a ->
    (PConcrete edsl a -> Term edsl b) ->
    Term edsl b
  pcase ::
    forall b.
    (HasCallStack, IsPType edsl b) =>
    Term edsl a ->
    (PConcrete edsl a -> PEffect edsl (Term edsl b)) ->
    PEffect edsl (Term edsl b)

-- duplicate IsPType' constraint because otherwise GHC complains
instance (PIsRepr (PReprSort a), PReprC (PReprSort a) a, IsPType' edsl (PRepr a), PConstructable' edsl (PRepr a)) => PConstructable edsl a where
  pcon x = Term $ pconImpl (prfrom x)
  pmatch (Term t) f = pmatchImpl t \x -> f (prto x)
  pcase (Term t) f = pcaseImpl t \x -> f (prto x)

class PDSL edsl => PAp (f :: Type -> Type) edsl where
  papr :: HasCallStack => f a -> Term edsl b -> Term edsl b
  papl :: HasCallStack => Term edsl a -> f b -> Term edsl a

class PAp m edsl => PEmbeds (m :: Type -> Type) edsl where
  pembed :: HasCallStack => m (Term edsl a) -> Term edsl a

type CompileAp variant output =
  forall a m.
  (HasCallStack, Applicative m, (forall edsl. variant edsl => IsPType edsl a)) =>
  (forall edsl. (variant edsl, PAp m edsl) => Term edsl a) ->
  m output

type Compile variant output =
  forall a m.
  (HasCallStack, Monad m, (forall edsl. variant edsl => IsPType edsl a)) =>
  (forall edsl. (variant edsl, PEmbeds m edsl) => Term edsl a) ->
  m output

instance
  ( PConstructable e r
  , IsPType e a
  , HasField name (PConcrete e r) (Term e a)
  ) =>
  HasField name (Term e r) (Term e a)
  where
  getField x = pmatch x \x' -> getField @name x'
