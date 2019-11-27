{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TypeFamilies               #-}

module Grading.Server.Handlers
    ( gradingServerT
    ) where

import Control.Exception       (try, Exception (..), SomeException)
import Data.Time.Clock.POSIX   (getCurrentTime)
import Database.SQLite.Simple
import Servant

import Grading.API
import Grading.Server.GradingM
import Grading.Types
import Grading.Utils.Submit    (submitArchive)
import Grading.Utils.Tar       (CheckedArchive, checkArchive_)

gradingServerT :: ServerT GradingAPI GradingM
gradingServerT = 
         addUserHandler
    :<|> usersHandler
    :<|> addTaskHandler
    :<|> getTaskHandler
    :<|> uploadHandler

addUserHandler :: UserName -> EMail -> GradingM NoContent
addUserHandler n e = do
    let u = User n e
    res <- withDB $ \conn -> liftIO $ try $ execute conn "INSERT INTO users (id, email) VALUES (?,?)" (n, e)
    case res of
        Left (err :: SomeException) -> do
            logMsg $ "ERROR adding user " ++ show u ++ ": " ++ show err
            throwError err400
        Right ()                    -> do
            logMsg $ "added user " ++ show u
            return NoContent

usersHandler :: GradingM [User]
usersHandler = withDB $ \conn -> liftIO $ query_ conn "SELECT * FROM users ORDER BY id ASC"

addTaskHandler :: TaskDescription -> GradingM TaskId
addTaskHandler td = do
    let d = tdImage td
    res <- withDB $ \conn -> liftIO $ try $ do
        execute conn "INSERT INTO tasks (image, archive) VALUES (?,?)" (d, tdArchive td)
        [Only tid] <- query_ conn "SELECT last_insert_rowid()"
        return tid 
    case res of
        Left (err :: SomeException) -> do
            logMsg $ "ERROR adding task with image " ++ show d ++ ": " ++ show err
            throwError err400
        Right tid                   -> do
            logMsg $ "added task " ++ show tid
            return tid

getTaskHandler :: TaskId -> GradingM CheckedArchive
getTaskHandler tid = do
    echecked <- withDB $ \conn -> liftIO $ try $ do
        [Only a] <- query conn "SELECT archive FROM tasks where id = ?" (Only tid)
        return a
    case echecked of
        Right checked             -> do
            logMsg $ "downloaded task " ++ show tid
            return checked
        Left (e :: SomeException) -> do
            logMsg $ "ERROR downloading task " ++ show tid ++ ": " ++ displayException e
            throwError err400

uploadHandler :: UserName -> TaskId -> UncheckedArchive -> GradingM (SubmissionId, TestsAndHints)
uploadHandler n tid unchecked = do
    let msg ="upload request from user " ++ show n ++ " for task " ++ show tid ++ ": "
    e <- withDB $ \conn -> liftIO $ try $ do
        checked  <- checkArchive_ unchecked
        [Only d] <- query conn "SELECT image FROM tasks WHERE id = ?" (Only tid)
        res      <- submitArchive d checked
        case res of
            Tested th -> do
                now <- getCurrentTime
                execute conn "INSERT INTO submissions (userid, taskid, time, archive, result) VALUES (?,?,?,?,?)" (n, tid, now, checked, th)
                [Only sid] <- query_ conn "SELECT last_insert_rowid()"
                return (sid, th)
            _         -> ioError $ userError $ show res
    case e of
        Left (err :: SomeException) -> do
            logMsg $ msg ++ "ERROR - " ++ displayException err
            throwError err400
        Right x@(sid, _)            -> do
            logMsg $ msg ++ "OK - created submission " ++ show sid
            return x
