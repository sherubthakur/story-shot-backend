{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE AllowAmbiguousTypes #-}


module Resource.Author
  ( getAuthors
  , getAuthor
  , createAuthors
  , createAuthor
  , updateAuthors
  , updateAuthor
  , deleteAuthors
  , deleteAuthor
  ) where


import qualified Init as I
import qualified Type.Pagination as TP
import qualified Type.Doc as TD
import qualified Type.Author as TA
import qualified Type.Meta as TM
import qualified Storage.Author as SA



-- CREATE

createAuthor :: TA.AuthorInsert -> I.AppT TA.Author
createAuthor = SA.createAuthor


createAuthors :: [TA.AuthorInsert] -> I.AppT [TA.Author]
createAuthors = SA.createAuthors



-- RETRIVE

getAuthors :: TP.CursorParam -> I.AppT [TA.Author]
getAuthors = SA.getAuthors


getAuthor :: Int -> I.AppT (Maybe TA.Author)
getAuthor = SA.getAuthor



-- UPDATE

updateAuthor :: TA.AuthorPut -> I.AppT (Maybe TA.Author)
updateAuthor = SA.updateAuthor


updateAuthors :: [TA.AuthorPut] -> I.AppT [TA.Author]
updateAuthors = SA.updateAuthors



-- DELETE

deleteAuthor :: Int -> I.AppT Int
deleteAuthor = fmap fromIntegral . SA.deleteAuthor


deleteAuthors :: [Int] -> I.AppT Int
deleteAuthors = fmap fromIntegral . SA.deleteAuthors
