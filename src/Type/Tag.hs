{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE RecordWildCards       #-}
{-# LANGUAGE TemplateHaskell       #-}


module Type.Tag
  ( Tag
  , TagInsert
  , TagPut
  , TagWrite
  , TagRead
  , TagS
  , tagTable
  , mkTagS
  , mkTagPut
  , mkTagWrite
  , mkTagWrite'
  , tagID
  , tagColID
  , tagName
  , tagColName
  , validTagInsertObject
  , validTagPutObject
  ) where


import           Data.Aeson                 ((.:), (.=))
import           Data.Monoid                ((<>))

import qualified Data.Time                  as DT
import qualified GHC.Generics               as Generics

import qualified Data.Aeson                 as Aeson
import qualified Data.Profunctor.Product.TH as ProductProfunctor
import qualified Data.Text                  as Text
import qualified Opaleye                    as O

import qualified Class.Resource             as CR



-- Strangely Polymorphic data type (Internal Use)

data Tag' id' name createdAt updatedAt =
  Tag
    { _tagID     :: id'
    , _tagName   :: name
    , _createdAt :: createdAt
    , _updatedAt :: updatedAt
    } deriving (Eq, Show, Generics.Generic)


-- Types that Will be used

type Tag = Tag' Int Text.Text DT.UTCTime DT.UTCTime
type TagS = Tag' Int () () ()
type TagPut = Tag' Int Text.Text () ()
type TagInsert = Tag' () Text.Text () ()
type TagRead = Tag'
  (O.Column O.PGInt4)
  (O.Column O.PGText)
  (O.Column O.PGTimestamptz)
  (O.Column O.PGTimestamptz)
type TagWrite = Tag'
  (Maybe (O.Column O.PGInt4))
  (O.Column O.PGText)
  (Maybe (O.Column O.PGTimestamptz))
  (Maybe (O.Column O.PGTimestamptz))


instance CR.Resource Tag where
  rid  = _tagID
  createdAt = _createdAt
  updatedAt = _updatedAt
  type' _ = "tag"



-- Magic

$(ProductProfunctor.makeAdaptorAndInstance "pTag" ''Tag')



-- Opaleye table binding

tagTable :: O.Table TagWrite TagRead
tagTable = O.Table "tags" $
  pTag
    Tag
      { _tagID = O.optional "id"
      , _tagName = O.required "name"
      , _createdAt = O.optional "created_at"
      , _updatedAt = O.optional "updated_at"
      }



-- Some Helpers

mkTagPut :: Int -> Text.Text -> TagPut
mkTagPut tid name = Tag
  { _tagID = tid
  , _tagName = name
  , _createdAt = ()
  , _updatedAt = ()
  }


mkTagS :: Int -> TagS
mkTagS tid = Tag
  { _tagID = tid
  , _tagName = ()
  , _createdAt = ()
  , _updatedAt = ()
  }


mkTagWrite' :: TagInsert -> TagWrite
mkTagWrite' Tag{..} = Tag
  { _tagID = Nothing
  , _tagName = O.constant _tagName
  , _createdAt = Nothing
  , _updatedAt = Nothing
  }


mkTagWrite :: TagPut -> TagWrite
mkTagWrite Tag{..} = Tag
  { _tagID = O.constant $ Just _tagID
  , _tagName = O.constant _tagName
  , _createdAt = Nothing
  , _updatedAt = Nothing
  }


tagID :: Tag' Int b c d -> Int
tagID = _tagID


tagName :: Tag' a Text.Text c d -> Text.Text
tagName = _tagName


tagColID :: TagRead -> O.Column O.PGInt4
tagColID = _tagID


tagColName :: TagRead -> O.Column O.PGText
tagColName = _tagName



-- JSON

instance Aeson.ToJSON Tag where
  toJSON Tag{..} = Aeson.object
    [ "id" .= _tagID
    , "name" .= _tagName
    , "created-at" .= _createdAt
    , "updated-at" .= _updatedAt
    , "type" .= ("tag" :: Text.Text)
    , "link" .= ((Text.pack $ "/tag/" <> show _tagID) :: Text.Text)
    ]


instance Aeson.ToJSON TagS where
  toJSON Tag{..} = Aeson.object
    [ "id" .= _tagID
    , "type" .= ("tag" :: Text.Text)
    , "link" .= ((Text.pack $ "/tag/" <> show _tagID) :: Text.Text)
    ]


instance Aeson.FromJSON TagS where
  parseJSON = Aeson.withObject "tag" $ \o -> Tag
    <$> o .: "id"
    <*> pure ()
    <*> pure ()
    <*> pure ()


instance Aeson.FromJSON Tag where
  parseJSON = Aeson.withObject "tag" $ \o -> Tag
    <$> o .: "id"
    <*> o .: "name"
    <*> o .: "created-at"
    <*> o .: "updated-at"


instance Aeson.FromJSON TagInsert where
  parseJSON = Aeson.withObject "tag" $ \o -> Tag
    <$> pure ()
    <*> o .: "name"
    <*> pure ()
    <*> pure ()


instance Aeson.FromJSON TagPut where
  parseJSON = Aeson.withObject "tag" $ \o -> Tag
    <$> o .: "id"
    <*> o .: "name"
    <*> pure ()
    <*> pure ()


-- Valid Request Hints

validTagInsertObject :: Aeson.Value
validTagInsertObject = Aeson.object
  [ "name" .= ("The name you want to give to this tag you are creating" :: Text.Text)
  ]


validTagPutObject :: Aeson.Value
validTagPutObject = Aeson.object
  [ "id" .= ("The id of the tag which should be in the DB" :: Text.Text)
  , "name" .= ("The name you want to give to the tag with the above id" :: Text.Text)
  ]
