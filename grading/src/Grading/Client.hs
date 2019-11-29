module Grading.Client
    ( User
    , getPort
    , addUserIO
    , usersIO
    , addTaskIO
    , getTaskIO
    , getSubmissionIO
    , postSubmissionIO
    ) where

import Codec.Archive.Tar      (pack, write)
import Codec.Compression.GZip (compress)
import Control.Exception      (throwIO)
import Control.Monad          (unless, void)
import Network.HTTP.Client    (newManager, defaultManagerSettings)
import Servant
import Servant.Client
import System.Directory       (doesDirectoryExist, makeAbsolute)
import System.IO.Error        (userError)

import Grading.API
import Grading.Server         (getPort)
import Grading.Submission
import Grading.Types
import Grading.Utils.Tar      (CheckedArchive)

addUser        :: UserName -> EMail -> ClientM NoContent
users          :: ClientM [User]
addTask        :: TaskDescription -> ClientM TaskId
getTask        :: TaskId -> ClientM CheckedArchive
getSubmission  :: SubmissionId -> ClientM Submission
postSubmission :: UserName -> TaskId -> UncheckedArchive -> ClientM Submission
addUser :<|> users :<|> addTask :<|> getTask :<|> getSubmission :<|> postSubmission = client gradingAPI

clientIO :: String -> Int -> ClientM a -> IO a
clientIO host port c = do
    m <- newManager defaultManagerSettings
    let env = mkClientEnv m $ BaseUrl Http host port ""
    res <- runClientM c env
    case res of
        Left err -> throwIO $ userError $ show err
        Right a  -> return a

addUserIO :: String -> Int -> User -> IO ()
addUserIO host port u = void $ clientIO host port $ addUser (userName u) (userEMail u)

usersIO :: String -> Int -> IO [User]
usersIO host port = clientIO host port users

addTaskIO :: String -> Int -> TaskDescription -> IO TaskId
addTaskIO host port td = clientIO host port $ addTask td

getTaskIO :: String -> Int -> TaskId -> IO CheckedArchive
getTaskIO host port tid = clientIO host port $ getTask tid

getSubmissionIO :: String -> Int -> SubmissionId -> IO Submission
getSubmissionIO host port sid = clientIO host port $ getSubmission sid

postSubmissionIO :: String -> Int -> UserName -> TaskId -> FilePath -> IO Submission
postSubmissionIO host port n tid fp = do
    nfp       <- normFolder fp
    unchecked <- UncheckedArchive . compress . write <$> pack nfp ["."]
    clientIO host port $ postSubmission n tid unchecked

normFolder :: FilePath -> IO FilePath
normFolder f = do
    b <- doesDirectoryExist f
    unless b $ throwIO $ userError $ "folder " ++ show f ++ " does not exists"
    makeAbsolute f
