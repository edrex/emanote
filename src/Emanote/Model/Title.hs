{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeApplications #-}

module Emanote.Model.Title
  ( Title,

    -- * Title conversion
    fromRoute,
    fromInlines,
    toInlines,

    -- * Rendering a Title
    titleSplice,
    titleSpliceNoHtml,
  )
where

import Data.Aeson (ToJSON)
import qualified Emanote.Route as R
import qualified Heist.Extra.Splices.Pandoc as HP
import Heist.Extra.Splices.Pandoc.Render (plainify)
import qualified Heist.Interpreted as HI
import Relude
import qualified Text.Pandoc.Definition as B
import qualified Text.Pandoc.Walk as W

data Title
  = TitlePlain Text
  | TitlePandoc [B.Inline]
  deriving (Show, Generic, ToJSON)

instance Eq Title where
  (==) =
    -- Use toPlain here, rather than toInlines, because the same text can have
    -- different inlines structure. For example, "Foo Bar" can be represented as
    --   [Str "Foo", Space, Str "Bar"],
    -- or as,
    --   [Str "Foo Bar"]
    on (==) toPlain

instance Ord Title where
  compare =
    on compare toPlain

instance Semigroup Title where
  TitlePlain a <> TitlePlain b =
    TitlePlain (a <> b)
  x <> y =
    TitlePandoc $ on (<>) toInlines x y

instance IsString Title where
  fromString = TitlePlain . toText

fromRoute :: R.LMLRoute -> Title
fromRoute =
  TitlePlain . R.routeBaseName . R.lmlRouteCase

fromInlines :: [B.Inline] -> Title
fromInlines = TitlePandoc

toInlines :: Title -> [B.Inline]
toInlines = \case
  TitlePlain s -> one (B.Str s)
  TitlePandoc is -> is

toPlain :: Title -> Text
toPlain = \case
  TitlePlain s -> s
  TitlePandoc is -> plainify is

titleSplice ::
  forall b n.
  (Monad n, W.Walkable B.Inline b, b ~ [B.Inline]) =>
  HP.RenderCtx n ->
  (b -> b) ->
  Title ->
  HI.Splice n
titleSplice ctx f = \case
  TitlePlain x ->
    HI.textSplice x
  TitlePandoc is -> do
    let titleDoc = B.Pandoc mempty $ one $ B.Plain $ f is
    HP.pandocSplice ctx titleDoc

titleSpliceNoHtml :: Monad n => Title -> HI.Splice n
titleSpliceNoHtml =
  HI.textSplice . toPlain
