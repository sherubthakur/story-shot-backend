{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE InstanceSigs        #-}
{-# LANGUAGE OverloadedStrings   #-}


module Resource.User
  ( getUsers
  , getUser
  , createUsers
  , createUser
  , updateUsers
  , updateUser
  , deleteUsers
  , deleteUser
  ) where


import qualified Data.Map        as M

import qualified Class.Resource  as CR
import qualified Init            as I
import qualified Library.Link    as LL
import qualified Storage.Author  as SA
import qualified Storage.User    as SU
import qualified Type.Author     as TA
import qualified Type.Include    as Include
import qualified Type.Or         as Or
import qualified Type.Pagination as TP
import qualified Type.User       as TU



-- CREATE

createUser :: [Include.Include] -> TU.UserInsert -> I.AppT TU.User
createUser includes user = do
  author <- SA.createAuthor $ TA.mkAuthorInsert $ TU.userName user
  user' <- SU.createUser user author
  return . head $ _linkAll includes [user'] [author]


createUsers :: [Include.Include] -> [TU.UserInsert] -> I.AppT [TU.User]
createUsers includes users = do
  authors <- SA.createAuthors $ fmap (TA.mkAuthorInsert . TU.userName) users
  users' <- SU.createUsers users authors
  return $ _linkAll includes users' authors



-- RETRIVE

getUsers :: TP.CursorParam -> [Include.Include]-> I.AppT [TU.User]
getUsers cur includes =
  SU.getUsers cur >>= _fromPGUsers includes


getUser :: Int -> [Include.Include] -> I.AppT (Maybe TU.User)
getUser sid includes = do
  mstory <- SU.getUser sid
  case mstory of
    Nothing      -> return Nothing
    Just pguser -> do
      mauthor <- LL.getResourceForResource includes (Include.Author, SA.getAuthor, TA.mkAuthorS, TU.userAuthorID pguser)
      case mauthor of
        Nothing     -> return Nothing
        Just author -> return . Just $ TU.mkLinkedUser pguser author



_linkAll :: [Include.Include] -> [TU.PGUser] -> [TA.Author] -> [TU.User]
_linkAll [] users _ = zipWith TU.mkUserFromDB users $ fmap (Or.Or . Left . TA.mkAuthorS . TU.userAuthorID) users
_linkAll [Include.Author] users authors =
  let
    aMap = M.fromList [(TA.authorID author, author) | author <- authors]
    authors' = fmap (Or.Or . Right . (aMap M.!) . TU.userAuthorID) users
  in
    zipWith TU.mkUserFromDB users authors'
_linkAll _ _ _ = error "Undefined is not a function"


_fromPGUsers :: [Include.Include] -> [TU.PGUser] -> I.AppT [TU.User]
_fromPGUsers includes users = do
  let
    userIDs = map TU.pgUserID users
    authorIDs = map TU.userAuthorID users
    userAuthorIDMap = M.fromList $ zip userIDs authorIDs
  authors <- LL.getResourceForResources includes (Include.Author, SA.getMultiAuthors, TA.mkAuthorS, userAuthorIDMap)
  let
    mkLinkedResource pg = TU.mkLinkedUser pg (LL.getResource pid authors)
      where pid = CR.urid pg
  return $ fmap mkLinkedResource users


-- UPDATE

updateUser :: TU.UserPut -> I.AppT (Maybe TU.User)
updateUser = undefined -- fmap TM.docOrError . SU.updateUser


updateUsers :: [TU.UserPut] -> I.AppT [TU.User]
updateUsers = undefined -- fmap TM.docMulti . SU.updateUsers



-- DELETE

deleteUser :: Int -> I.AppT Int
deleteUser = fmap fromIntegral . SU.deleteUser


deleteUsers :: [Int] -> I.AppT Int
deleteUsers = fmap fromIntegral . SU.deleteUsers
