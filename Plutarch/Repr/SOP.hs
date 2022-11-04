{-# LANGUAGE FlexibleInstances #-}

module Plutarch.Repr.SOP (PReprSOP, PSOPed (PSOPed)) where

import Data.Coerce (coerce)
import Plutarch.Internal.Unimplemented (Error, Unimplemented)
import Plutarch.PType (
  PGeneric,
  PType,
 )
import Plutarch.Repr (PIsRepr (PReprApplyVal0, PReprC, prIsPType, prfrom, prto), PIsRepr0 (PReprApply, PReprIsPType), PReprKind (PReprKind))

data PReprSOP'

-- | Representation as a SOP. Requires 'PGeneric'.
type PReprSOP = 'PReprKind PReprSOP'

newtype PSOPed (a :: PType) ef = PSOPed (a ef)

instance PIsRepr0 PReprSOP where
  type PReprApply PReprSOP a = PSOPed a

  -- Maybe: `Known x => IsPType' edsl x`
  type PReprIsPType _ _ _ _ = Unimplemented "PReprIsPType PReprSOP"

instance PIsRepr PReprSOP where
  type PReprC PReprSOP a = PGeneric a
  type PReprApplyVal0 _ _ _ _ = Error "PReprApplyVal0 PReprSOP"
  prIsPType _ _ _ = error "unimplemented"
  prfrom = coerce
  prto = coerce