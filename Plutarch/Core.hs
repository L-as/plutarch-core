module Plutarch.Core (
  Term(..),
  runInterpreter,
  Interpret(..),
  Term'(..),
  InterpretAllIn(..), InterpretIn(..), Permute(..), ListEqMod1(..), SubLS(..), Tag, Language, L) where

import Data.Kind (Type)

type Tag = Type
type Language = Type
type L :: Language -> [Language] -> Tag -> Type
data family L l ls tag

-- | Isomorphic to naturals.
-- @ListEqMod1 xs ys x@ tells us that @xs@ is equal to @ys@, modulo @x@,
-- i.e., if you remove a specific @x@ from @ys@, you get @xs@.
-- You can also think of it as inserting @x@ into @xs@, resulting in @ys@.
-- Representationally it is an index into a list.
type ListEqMod1 :: [a] -> [a] -> a -> Type
data ListEqMod1 xs ys x where
  ListEqMod1N :: ListEqMod1 xs (x : xs) x
  ListEqMod1S :: ListEqMod1 xs ys x -> ListEqMod1 (y : xs) (y : ys) x

-- | @Permute xs ys@ tells us we can permute @xs@ into @ys@.
-- The proof of that is a list of indices into @ys@, each one
-- being the corresponding index from the element in @xs@ into @ys@.
type Permute :: [a] -> [a] -> Type
data Permute xs ys where
  PermuteN :: Permute '[] '[]
  PermuteS :: ListEqMod1 ys ys' x -> Permute xs ys -> Permute (x : xs) ys'

-- @SubLS xs ys zs ws (Just '(x, y))@ shows that @xs@ and @ys@ share a common suffix,
-- with the prefix containing @zs@ in @xs@ and @ws@ in @ys@, except for @x@ and @y@.
type SubLS :: [Language] -> [Language] -> [Language] -> [Language] -> Maybe (Language, Language) -> Type
data SubLS xs ys zs ws except where
  SubLSBase :: SubLS xs xs '[] '[] Nothing
  SubLSSwap :: SubLS xs ys zs ws except -> SubLS (x : xs) (y : ys) (x : zs) (y : ws) except
  SubLSSkip :: SubLS xs ys zs ws except -> SubLS xs ys (x : zs) (y : ws) except
  SubLSExcept :: SubLS xs ys zs ws Nothing -> SubLS xs ys (x : zs) (y : ws) (Just '(x, y))

-- | Interpret a term of root language l to
-- a term of root language l'. The inner languages
-- are mappped from ls to ls'.
type InterpretIn :: [Language] -> [Language] -> Language -> Language -> Type
newtype InterpretIn ls ls' l l'
  = InterpretIn
    (forall ls0 ls1 tag.
      SubLS ls0 ls1 ls ls' (Just '(l, l')) ->
      Term' l ls0 tag ->
      Term' l' ls1 tag
    )

runInterpreter ::
  InterpretIn ls ls' l l' ->
  SubLS ls0 ls1 ls ls' (Just '(l, l')) ->
  Term' l ls0 tag ->
  Term' l' ls1 tag
runInterpreter (InterpretIn f) = f

-- | @InterpretAllIn ls0 ls1 ls2 ls3@ contains functions to
-- interpret terms which root nodes are in the languages of @ls2@ into
-- root nodes which languages are of @ls3@, while mapping the inner languages
-- from @ls0@ to @ls1@.
type InterpretAllIn :: [Language] -> [Language] -> [Language] -> [Language] -> Type
data InterpretAllIn ls0 ls1 ls2 ls3 where
  InterpretAllInN :: InterpretAllIn ls0 ls1 '[] '[]
  InterpretAllInS :: InterpretIn ls0 ls1 l l' -> InterpretAllIn ls0 ls1 ls2 ls3 -> InterpretAllIn ls0 ls1 (l : ls2) (l' : ls3)

-- | @Interpret ls ls'@ contains functions to interpret the languages @ls@ to @ls'@.
type Interpret :: [Language] -> [Language] -> Type
newtype Interpret ls ls' = Interpret (InterpretAllIn ls ls' ls ls')

-- | Like @Term@, but explicitly notes the language of the root node.
type Term' :: Language -> [Language] -> Tag -> Type
data Term' l ls tag where
  Term' :: L l ls0 tag -> Interpret ls0 ls1 -> Permute ls1 ls2 -> Term' l ls2 tag

-- | @Term ls tag@ represents a term in the languages of @ls@,
-- with the tag @tag@, often representing an embedded type.
type Term :: [Language] -> Tag -> Type
data Term ls tag where
  Term :: Term' l ls tag -> ListEqMod1 ls ls' l -> Term ls' tag

