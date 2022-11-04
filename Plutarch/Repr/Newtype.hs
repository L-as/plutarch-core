{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}

module Plutarch.Repr.Newtype (PReprNewtype) where

import Data.Coerce (Coercible, coerce)
import Plutarch.Internal.Unimplemented (Error, Unimplemented)
import Plutarch.PType (
  PCode,
  PGeneric,
  PType,
 )
import Plutarch.Repr (PIsRepr (PReprApplyVal0, PReprC, prIsPType, prfrom, prto), PIsRepr0 (PReprApply, PReprIsPType), PReprKind (PReprKind))

type family GetPNewtype' (a :: [[PType]]) :: PType where
  GetPNewtype' '[ '[a]] = a

type family GetPNewtype (a :: PType) :: PType where
  GetPNewtype a = GetPNewtype' (PCode a)

data PReprNewtype'

-- | Representation as a Newtype. Requires 'PGeneric'.
type PReprNewtype = 'PReprKind PReprNewtype'

instance PIsRepr0 PReprNewtype where
  type PReprApply PReprNewtype a = GetPNewtype a
  type PReprIsPType _ _ _ _ = Unimplemented "PReprIsPType PReprNewtype"

instance PIsRepr PReprNewtype where
  type PReprC PReprNewtype a = (PGeneric a, Coercible a (GetPNewtype a))
  type PReprApplyVal0 _ _ _ _ = Error "PReprApplyVal0 PReprNewtype"
  prIsPType _ _ _ = error "unimplemented"
  prfrom = coerce
  prto = coerce