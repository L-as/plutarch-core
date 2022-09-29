{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE UndecidableSuperClasses #-}

module Plutarch.Core (
  PGeneric,
  Compile,
  CompileAp,
  PRepr,
  PDSLKind (..),
  UnPDSLKind,
  Term (Term),
  ClosedTerm,
  IsPType',
  PHasRepr (..),
  PIsRepr (..),
  IsPType,
  isPType,
  PReprPrimitive,
  PReprSOP,
  PHs,
  PConcrete,
  PConstructable' (pconImpl, pmatchImpl),
  PConstructable,
  pcon,
  pmatch,
  type (#->),
  pattern PLam,
  type (#=>),
  pattern PConstrained,
  PVoid,
  PLet (..),
  PDelay (PDelay),
  PPair (PPair),
  PEither (PLeft, PRight),
  PForall (PForall),
  PSome (PSome),
  PFix (PFix),
  PAny (PAny),
  PPolymorphic,
  PIsSOP,
  PUnit (PUnit),
  PDSL,
  PLC,
  unTerm,
  (#),
  plet,
  punsafeCoerce,
  PUntyped,
  PPartial,
  perror,
  PEmbeds,
  pembed,
  PAp,
  papr,
  papl,
  PIsProduct,
  PIsSum,
  sopFrom,
  sopTo,
) where

import Data.Functor.Compose (Compose)
import Data.Kind (Constraint, Type)
import Data.Proxy (Proxy (Proxy))
import GHC.Generics (Generic)
import GHC.Stack (HasCallStack)
import GHC.TypeLits (Symbol)
import Generics.SOP qualified as SOP
import Generics.SOP.Constraint qualified as SOP
import Generics.SOP.GGP qualified as SOPG
import Plutarch.PType (
  PGeneric,
  PHs,
  PPType,
  PType,
  PTypeF,
  PfC,
  pattern MkETypeF,
  type (/$),
 )
import Plutarch.Reduce (NoReduce)

newtype PDSLKind = PDSLKind (PType -> Type)

type family UnPDSLKind (edsl :: PDSLKind) :: PType -> Type where
  UnPDSLKind ( 'PDSLKind edsl) = edsl

newtype PReprKind = PReprKind Type

{- | A "representation" of a type. This defines how a user-visible type
 is mapped onto a type in the backend.
-}
class PIsRepr (r :: PReprKind) where
  type PReprApply r (a :: PType) :: PType
  type PReprC r (a :: PType) :: Constraint
  type PReprIsPType r (a :: PType) (edsl :: PDSLKind) (x :: PHs a) :: Constraint
  prfrom :: (PHasRepr a, PReprSort a ~ r) => a ef -> PReprApply r a ef
  prto :: (PHasRepr a, PReprSort a ~ r) => PReprApply r a ef -> a ef
  prIsPType ::
    forall edsl a (x :: PHs a) y.
    (PHasRepr a, PReprSort a ~ r, PReprIsPType r a edsl x) =>
    Proxy r ->
    Proxy edsl ->
    Proxy x ->
    (forall a' (x' :: PHs a'). IsPType' edsl x' => Proxy x' -> y) ->
    y

data PReprPrimitive'

-- | The "identity" representation.
type PReprPrimitive = 'PReprKind PReprPrimitive'

instance PIsRepr PReprPrimitive where
  type PReprApply PReprPrimitive a = a
  type PReprC PReprPrimitive _ = ()
  type PReprIsPType PReprPrimitive _ edsl x = IsPType' edsl x
  prfrom = id
  prto = id
  prIsPType _ _ x f = f x

data PReprSOP'

-- | Representation as a SOP. Requires 'PGeneric'.
type PReprSOP = 'PReprKind PReprSOP'

newtype PSOPed (a :: PType) ef = PSOPed (a ef)

type family Unimplemented (t :: Symbol) :: Constraint where

instance PIsRepr PReprSOP where
  type PReprApply PReprSOP a = PSOPed a
  type PReprC PReprSOP a = PGeneric a
  type PReprIsPType _ _ _ _ = Unimplemented "It is not yet clear how to handle this" -- Known x => IsPType' edsl x
  prfrom = PSOPed
  prto (PSOPed x) = x
  prIsPType _ _ _ _ = error "unimplemented"

class (PIsRepr (PReprSort a), PReprC (PReprSort a) a) => PHasRepr (a :: PType) where
  type PReprSort a :: PReprKind
  type PReprSort _ = PReprSOP

instance PHasRepr PPType where
  type PReprSort _ = PReprPrimitive

type PRepr :: PType -> PType
type PRepr a = PReprApply (PReprSort a) a

type NoTypeInfo :: forall k. PHs k -> Constraint
class NoTypeInfo a
instance NoTypeInfo a

class PDSL (edsl :: PDSLKind) where
  type IsPType' edsl :: forall (a :: PType). PHs a -> Constraint
  type IsPType' _ = NoTypeInfo

type role Term nominal nominal
newtype Term (edsl :: PDSLKind) (a :: PType) where
  Term :: {unTerm :: UnPDSLKind edsl (PRepr a)} -> Term edsl a

type ClosedTerm (c :: PDSLKind -> Constraint) (a :: PType) = forall edsl. c edsl => Term edsl a

type IsPTypeWrapper :: Bool -> PDSLKind -> forall (a :: PType). PHs a -> Constraint
class IsPTypeWrapper typeorval edsl x where
  isPTypeWrapper :: Proxy typeorval -> Proxy edsl -> Proxy x -> (forall a' (x' :: PHs a'). IsPType' edsl x' => Proxy x' -> y) -> y

instance (PHasRepr a, IsPType' edsl @PPType (PRepr a)) => IsPTypeWrapper 'True edsl (a :: PType) where
  isPTypeWrapper _ _ _ f = f (Proxy @(PRepr a))

instance (PHasRepr a, PReprIsPType (PReprSort a) a edsl x) => IsPTypeWrapper 'False edsl (x :: PHs a) where
  isPTypeWrapper _ edsl x f = prIsPType (Proxy @(PReprSort a)) edsl x f

type family TypeOrVal (a :: PType) :: Bool where
  TypeOrVal PPType = 'True
  TypeOrVal _ = 'False

type IsPType :: PDSLKind -> forall (a :: PType). PHs a -> Constraint
class IsPType edsl (x :: PHs a) where
  isPType :: forall y.
    Proxy edsl ->
    Proxy x ->
    (forall a' (x' :: PHs a'). IsPType' edsl x' => Proxy x' -> y) ->
    y
instance (IsPTypeWrapper (TypeOrVal a) edsl x) => IsPType edsl (x :: PHs a) where
  isPType = isPTypeWrapper (Proxy @(TypeOrVal a))

type CoerceTo :: forall a. forall (b :: Type) -> a -> b
type family CoerceTo (b :: Type) (x :: a) :: b where
  CoerceTo _ x = x

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
  Helper edsl = MkETypeF (H2 edsl) (Compose NoReduce (Term edsl))

type PConcrete (edsl :: PDSLKind) (a :: PType) = a (Helper edsl)

class (PDSL edsl, IsPType' edsl a) => PConstructable' edsl (a :: PType) where
  pconImpl :: HasCallStack => PConcrete edsl a -> UnPDSLKind edsl a
  pmatchImpl :: forall b. (HasCallStack, IsPType edsl b) => UnPDSLKind edsl a -> (PConcrete edsl a -> Term edsl b) -> Term edsl b

-- | The crux of what an eDSL is.
class IsPType edsl a => PConstructable edsl (a :: PType) where
  pcon :: HasCallStack => PConcrete edsl a -> Term edsl a
  pmatch ::
    forall b.
    (HasCallStack, IsPType edsl b) =>
    Term edsl a ->
    (PConcrete edsl a -> Term edsl b) ->
    Term edsl b

-- duplicate IsPType' constraint because otherwise GHC complains
instance (PHasRepr a, IsPType' edsl (PRepr a), PConstructable' edsl (PRepr a)) => PConstructable edsl a where
  pcon x = Term $ pconImpl (prfrom x)
  pmatch (Term t) f = pmatchImpl t \x -> f (prto x)

data PVoid ef
instance PHasRepr PVoid where type PReprSort _ = PReprPrimitive

-- | Pffects of `pcon` are effects of the argument.
data PLet a ef = PLet (ef /$ a)

instance PHasRepr (PLet a) where type PReprSort _ = PReprPrimitive

-- | `pcon` has no effects.
data PDelay a ef = PDelay (ef /$ a)

instance PHasRepr (PDelay a) where type PReprSort _ = PReprPrimitive

-- | '=>' embedded into an eDSL.
data (#=>) (a :: Constraint) (b :: PType) ef = PConstrained (a => ef /$ b)

instance PHasRepr (a #=> b) where type PReprSort _ = PReprPrimitive

infixr 0 #=>

-- | '->' embedded into an eDSL.
data (#->) a b ef = PLam ((ef /$ a) -> (ef /$ b)) deriving stock (Generic)

instance PHasRepr (a #-> b) where type PReprSort _ = PReprPrimitive

infixr 0 #->

data PAny ef = forall a. PAny (Proxy a) (ef /$ a)
instance PHasRepr PAny where type PReprSort _ = PReprPrimitive

newtype PForall (f :: PHs a -> PType) ef = PForall (forall (forallvar :: PHs a). PfC ef forallvar => ef /$ f forallvar)
instance PHasRepr (PForall ef) where type PReprSort _ = PReprPrimitive

data PSome (f :: PHs a -> PType) ef = forall (x :: PHs a). PSome (PfC ef x => ef /$ f x)
instance PHasRepr (PSome ef) where type PReprSort _ = PReprPrimitive

newtype PFix f ef = PFix (ef /$ f (PFix f))
instance PHasRepr (PFix f) where type PReprSort _ = PReprPrimitive

data PUnit (ef :: PTypeF) = PUnit deriving stock (Generic)
instance PHasRepr PUnit where type PReprSort _ = PReprPrimitive

data PPair a b ef = PPair (ef /$ a) (ef /$ b) deriving stock (Generic)
instance PHasRepr (PPair a b) where type PReprSort _ = PReprPrimitive

data PEither a b ef = PLeft (ef /$ a) | PRight (ef /$ b) deriving stock (Generic)
instance PHasRepr (PEither a b) where type PReprSort _ = PReprPrimitive

type PLC :: PDSLKind -> Constraint
type PLC edsl = forall a b. (IsPType edsl a, IsPType edsl b) => PConstructable edsl (a #-> b)

(#) :: (HasCallStack, PLC edsl, IsPType edsl a, IsPType edsl b) => Term edsl (a #-> b) -> Term edsl a -> Term edsl b
(#) f x = pmatch f (\(PLam f') -> f' x)

infixl 8 #

plet :: forall edsl a b. (HasCallStack, PConstructable edsl (PLet a), IsPType edsl b) => Term edsl a -> (Term edsl a -> Term edsl b) -> Term edsl b
plet x f = pmatch (pcon $ PLet x) \(PLet y) -> f y

class PDSL edsl => PUntyped edsl where
  punsafeCoerce :: (HasCallStack, IsPType edsl a, IsPType edsl b) => Term edsl a -> Term edsl b

type PPolymorphic :: PDSLKind -> Constraint
type PPolymorphic edsl =
  ( forall a (f :: PHs a -> PType). IsPType edsl ( 'PLam f :: PHs (a #-> PPType)) => PConstructable edsl (PForall f)
  , forall a b (f :: PHs a -> PHs b). (forall xVd. IsPType edsl xVd => IsPType edsl (f xVd)) => IsPType edsl ( 'PLam f :: PHs (a #-> b))
  )

class PDSL edsl => PPartial edsl where
  perror :: IsPType edsl a => Term edsl a

class PDSL edsl => PAp (f :: Type -> Type) edsl where
  papr :: HasCallStack => f a -> Term edsl b -> Term edsl b
  papl :: HasCallStack => Term edsl a -> f b -> Term edsl a

class PAp m edsl => PEmbeds (m :: Type -> Type) edsl where
  pembed :: HasCallStack => m (Term edsl a) -> Term edsl a

class
  ( SOP.AllZip (SOP.LiftedCoercible SOP.I (Term edsl)) ts (PPPTypes ts)
  , SOP.AllZip (SOP.LiftedCoercible (Term edsl) SOP.I) (PPPTypes ts) ts
  , SOP.All (IsPType edsl) (PPPTypes ts)
  ) =>
  PIsProduct (edsl :: PDSLKind) (ts :: [Type])
  where
  type PPPTypes ts :: [PType]
instance PIsProduct edsl '[] where
  type PPPTypes '[] = '[]
instance (IsPType edsl a, PIsProduct edsl ts) => PIsProduct edsl (Term edsl a : ts) where
  type PPPTypes (Term edsl a : ts) = a : PPPTypes ts

class
  ( SOP.AllZip2 (SOP.LiftedCoercible SOP.I (Term edsl)) tss (PSPTypes tss)
  , SOP.AllZip2 (SOP.LiftedCoercible (Term edsl) SOP.I) (PSPTypes tss) tss
  , SOP.SameShapeAs tss (PSPTypes tss)
  , SOP.SameShapeAs (PSPTypes tss) tss
  , SOP.AllZipF (SOP.AllZip (SOP.LiftedCoercible (Term edsl) SOP.I)) (PSPTypes tss) tss
  , SOP.AllZipF (SOP.AllZip (SOP.LiftedCoercible SOP.I (Term edsl))) tss (PSPTypes tss)
  , SOP.All2 (IsPType edsl) (PSPTypes tss)
  , SOP.SListI2 tss
  ) =>
  PIsSum (edsl :: PDSLKind) (tss :: [[Type]])
  where
  type PSPTypes (tss :: [[Type]]) :: [[PType]]
instance PIsSum edsl '[] where
  type PSPTypes '[] = '[]
instance (PIsProduct edsl ts, PIsSum edsl tss) => PIsSum edsl (ts : tss) where
  type PSPTypes (ts : tss) = PPPTypes ts : PSPTypes tss

type PSOPTerms edsl a = SOPG.GCode (PConcrete edsl a)
type PSOPPTypes edsl a = PSPTypes (PSOPTerms edsl a)

class
  ( PGeneric a
  , PIsSum edsl (PSOPTerms edsl a)
  , PReprSort a ~ PReprSOP
  ) =>
  PIsSOP (edsl :: PDSLKind) (a :: PType)

instance
  ( PGeneric a
  , PIsSum edsl (PSOPTerms edsl a)
  , PReprSort a ~ PReprSOP
  ) =>
  PIsSOP (edsl :: PDSLKind) (a :: PType)

sopFrom ::
  forall edsl a.
  PIsSOP edsl a =>
  Proxy edsl ->
  Proxy a ->
  SOP.SOP SOP.I (PSOPTerms edsl a) ->
  SOP.SOP (Term edsl) (PSOPPTypes edsl a)
sopFrom _ _ = SOP.hcoerce

sopTo ::
  forall edsl a.
  PIsSOP edsl a =>
  Proxy edsl ->
  Proxy a ->
  SOP.SOP (Term edsl) (PSOPPTypes edsl a) ->
  SOP.SOP SOP.I (PSOPTerms edsl a)
sopTo _ _ = SOP.hcoerce

type CompileAp variant output =
  forall a m.
  (PHasRepr a, HasCallStack, Applicative m, (forall edsl. variant edsl => IsPType edsl a)) =>
  (forall edsl. (variant edsl, PAp m edsl) => Term edsl a) ->
  m output

type Compile variant output =
  forall a m.
  (PHasRepr a, HasCallStack, Monad m, (forall edsl. variant edsl => IsPType edsl a)) =>
  (forall edsl. (variant edsl, PEmbeds m edsl) => Term edsl a) ->
  m output
