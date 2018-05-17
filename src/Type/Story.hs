{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE InstanceSigs #-}


module Type.Story
  ( Story
  , PGStory
  , StoryInsert
  , StoryPut
  , StoryPut'
  , StoryWrite
  , StoryRead
  , pgStoryID
  , storyTable
  , mkStoryPut
  , mkStoryWrite
  , mkStoryWrite'
  , mkStoryFromDB
  , mkLinkedStory
  , storyID
  , storyColID
  , tagIDs
  , validStoryPutObject
  , validStoryInsertObject
  ) where


import Data.Monoid ((<>))
import Data.Aeson ((.=), (.:))

import qualified Data.Time as DT
import qualified GHC.Generics as Generics

import qualified Data.Profunctor.Product.TH as ProductProfunctor
import qualified Data.Text as Text
import qualified Data.Aeson as Aeson
import qualified Opaleye as O

import qualified Class.Resource as CR
import qualified Type.Or as TO
import qualified Type.Genre as TG
import qualified Type.Tag as TT
import qualified Type.Author as TA



-- Ploymorphic Types

data Story' storyID title authors timesRead stars genre tags story createdAt updatedAt = Story
  { _storyID :: storyID
  , _title :: title
  , _authors :: authors
  , _timesRead :: timesRead
  , _stars :: stars
  , _genre :: genre
  , _tags :: tags
  , _story :: story
  , _createdAt :: createdAt
  , _updatedAt :: updatedAt
  } deriving (Eq, Show, Generics.Generic)


data PGStory' storyID title timesRead stars genre story createdAt updatedAt = PGStory
  { _pgStoryID :: storyID
  , _pgTitle :: title
  , _pgTimesRead :: timesRead
  , _pgStars :: stars
  , _pgGenre :: genre
  , _pgStory :: story
  , _pgCreatedAt :: createdAt
  , _pgUpdatedAt :: updatedAt
  } deriving (Eq, Show, Generics.Generic)


type Story = Story'
  Int
  Text.Text
  (TO.Or [TA.AuthorS] [TA.Author])
  Int
  Int
  TG.Genre
  (TO.Or [TT.TagS] [TT.Tag])
  Text.Text
  DT.UTCTime
  DT.UTCTime

type StoryS = Story' Int () () () () () () () () ()

type StoryPut    = Story' Int (Maybe Text.Text) (Maybe Int) (Maybe Int) (Maybe Int) (Maybe TG.Genre) (Maybe [Int]) (Maybe Text.Text) () ()
type StoryPut'   = Story' ()  (Maybe Text.Text) (Maybe Int) (Maybe Int) (Maybe Int) (Maybe TG.Genre) (Maybe [Int]) (Maybe Text.Text) () ()
type StoryInsert = Story' ()  Text.Text         Int         ()          ()          TG.Genre         [Int]         Text.Text         () ()

type PGStory   = PGStory' Int Text.Text Int Int TG.Genre Text.Text DT.UTCTime DT.UTCTime
type StoryRead = PGStory'
  (O.Column O.PGInt4)
  (O.Column O.PGText)
  (O.Column O.PGInt4)
  (O.Column O.PGInt4)
  (O.Column O.PGText)
  (O.Column O.PGText)
  (O.Column O.PGTimestamptz)
  (O.Column O.PGTimestamptz)

type StoryWrite = PGStory'
  (Maybe (O.Column O.PGInt4))
  (O.Column O.PGText)
  (O.Column O.PGInt4)
  (O.Column O.PGInt4)
  (O.Column O.PGText)
  (O.Column O.PGText)
  (Maybe (O.Column O.PGTimestamptz))
  (Maybe (O.Column O.PGTimestamptz))


instance CR.Resource Story where
  rid  = _storyID
  type' _ = "story"
  createdAt = _createdAt
  updatedAt = _updatedAt


instance CR.UnlinkedResource PGStory where
  urid = _pgStoryID


-- Magic

$(ProductProfunctor.makeAdaptorAndInstance "pStory" ''PGStory')



-- Opaleye table binding

storyTable :: O.Table StoryWrite StoryRead
storyTable = O.Table "stories" $ pStory
  PGStory
    { _pgStoryID = O.optional "id"
    , _pgTitle = O.required "title"
    , _pgTimesRead = O.required "times_read"
    , _pgStars = O.required "stars"
    , _pgGenre = O.required "genre"
    , _pgStory = O.required "story"
    , _pgCreatedAt = O.optional "created_at"
    , _pgUpdatedAt = O.optional "updated_at"
    }



-- Some Helpers


mkStoryFromDB :: PGStory -> TO.Or [TA.AuthorS] [TA.Author] -> TO.Or [TT.TagS] [TT.Tag] -> Story
mkStoryFromDB PGStory{..} author' tags' = Story
  { _storyID = _pgStoryID
  , _title = _pgTitle
  , _authors = author'
  , _timesRead = _pgTimesRead
  , _stars = _pgStars
  , _genre = _pgGenre
  , _story = _pgStory
  , _tags = tags'
  , _createdAt = _pgCreatedAt
  , _updatedAt = _pgUpdatedAt
  }

mkLinkedStory :: PGStory -> TO.Or [TA.AuthorS] [TA.Author] -> TO.Or [TT.TagS] [TT.Tag] -> Story
mkLinkedStory PGStory{..} authors tags = Story
  { _storyID = _pgStoryID
  , _title = _pgTitle
  , _authors = authors
  , _timesRead = _pgTimesRead
  , _stars = _pgStars
  , _genre = _pgGenre
  , _story = _pgStory
  , _tags = tags
  , _createdAt = _pgCreatedAt
  , _updatedAt = _pgUpdatedAt
  }


mkStoryWrite :: StoryInsert -> StoryWrite
mkStoryWrite Story{..} = PGStory
  { _pgStoryID = Nothing
  , _pgTitle = O.constant _title
  , _pgTimesRead = O.constant (0 :: Int)
  , _pgStars = O.constant (0 :: Int)
  , _pgGenre = O.constant _genre
  , _pgStory = O.constant _story
  , _pgCreatedAt = Nothing
  , _pgUpdatedAt = Nothing
  }


mkStoryWrite' :: StoryPut -> StoryRead -> StoryWrite
mkStoryWrite' Story{..} PGStory{..} = PGStory
  { _pgStoryID = Just $ O.constant _storyID
  , _pgTitle = maybe _pgTitle O.constant _title
  , _pgTimesRead = maybe _pgTimesRead O.constant _timesRead
  , _pgStars = maybe _pgStars O.constant _stars
  , _pgGenre = maybe _pgGenre O.constant _genre
  , _pgStory = maybe _pgStory O.constant _story
  , _pgCreatedAt = Nothing
  , _pgUpdatedAt = Nothing
  }


mkStoryPut :: Int -> StoryPut' -> StoryPut
mkStoryPut storyId Story{..} = Story
  { _storyID = storyId
  , _title = _title
  , _authors = _authors
  , _timesRead = _timesRead
  , _stars = _stars
  , _genre = _genre
  , _story = _story
  , _tags  = _tags
  , _createdAt = ()
  , _updatedAt = ()
  }
  

storyID :: Story' Int b c d e f g h i j -> Int
storyID = _storyID


tagIDs :: StoryInsert -> [Int]
tagIDs = _tags


pgStoryID :: PGStory' Int b c d e f g h -> Int
pgStoryID = _pgStoryID


storyColID :: PGStory' (O.Column O.PGInt4) b c d e f g h -> O.Column O.PGInt4
storyColID = _pgStoryID



-- JSON

instance Aeson.ToJSON Story where
  toJSON Story{..} = Aeson.object
    [ "id" .= _storyID
    , "title" .= _title
    , "authors" .= _authors
    , "tags" .= _tags
    , "read-count" .= _timesRead
    , "stars" .= _stars
    , "genre" .= _genre
    , "story" .= _story
    , "created-at" .= _createdAt
    , "updated-at" .= _updatedAt
    , "type" .= ("story" :: Text.Text)
    , "link" .= ((Text.pack $ "/story/" <> show _storyID) :: Text.Text)
    ]


instance Aeson.ToJSON StoryS where
  toJSON Story{..} = Aeson.object
    [ "id" .= _storyID
    , "type" .= ("story" :: Text.Text)
    , "link" .= ((Text.pack $ "/story/" <> show _storyID) :: Text.Text)
    ]


instance Aeson.FromJSON StoryInsert where
  parseJSON = Aeson.withObject "story" $ \o -> Story
      <$> pure ()
      <*> o .: "title"
      <*> o .: "authors"
      <*> pure ()
      <*> pure ()
      <*> o .: "genre"
      <*> o .: "tags"
      <*> o .: "story"
      <*> pure ()
      <*> pure ()


instance Aeson.FromJSON StoryPut where
  parseJSON = Aeson.withObject "story" $ \o -> Story
      <$> o .: "id"
      <*> o .: "title"
      <*> o .: "authors"
      <*> o .: "read-count"
      <*> o .: "stars"
      <*> o .: "genre"
      <*> o .: "tags"
      <*> o .: "story"
      <*> pure ()
      <*> pure ()


instance Aeson.FromJSON StoryPut' where
  parseJSON = Aeson.withObject "story" $ \o -> Story
      <$> pure ()
      <*> o .: "title"
      <*> o .: "authors"
      <*> o .: "read-count"
      <*> o .: "stars"
      <*> o .: "genre"
      <*> o .: "tags"
      <*> o .: "story"
      <*> pure ()
      <*> pure ()



-- Valid Request Hints

validStoryInsertObject :: Aeson.Value
validStoryInsertObject = Aeson.object
  [ "title" .= ("The title for the new story" :: Text.Text)
  , "author" .= ("The author-id's for the story (Should be in the DB)" :: Text.Text)
  , "genre" .= ("One of " ++ show TG.allGenres)
  , "tags" .= ("The list of tag-id's for this story" :: Text.Text)
  , "story" .= ("The story itself" :: Text.Text)
  ]


validStoryPutObject :: Aeson.Value
validStoryPutObject = Aeson.object
  [ "id" .= ("The id of the story which should be in the DB" :: Text.Text)
  , "title" .= ("The new/old title for the story with the above id" :: Text.Text)
  , "author" .= ("The new/old author-id's for the story with the above id" :: Text.Text)
  , "read-count" .= ("The new/old read-count for the story with the above id" :: Text.Text)
  , "stars" .= ("The new/old stars count for the story with the above id" :: Text.Text)
  , "genre" .= ("One of " ++ show TG.allGenres)
  , "tags" .= ("The new/old list of tag-id's for this story" :: Text.Text)
  , "story" .= ("The new/old value for the story" :: Text.Text)
  ]

