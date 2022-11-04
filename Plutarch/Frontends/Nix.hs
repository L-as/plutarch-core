{-# LANGUAGE UndecidableInstances #-}

module Plutarch.Frontends.Nix (PNix) where

import Plutarch.Core (PConstructable, PDSL)
import Plutarch.Frontends.Data (PAny, PSOP)
import Plutarch.Frontends.LC (PLC, PPolymorphic)
import Plutarch.Frontends.Untyped (PUntyped)

class
  ( PDSL e
  , PUntyped e
  , PLC e
  , -- , PPolymorphic e
    PConstructable e PAny
  , PSOP e
  ) =>
  PNix e