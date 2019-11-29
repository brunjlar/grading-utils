{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE DeriveAnyClass    #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators     #-}

module Main
    ( main
    ) where

import Data.Maybe         (fromMaybe)
import Options.Generic

import Grading.Client
import Grading.Submission
import Grading.Types
import Grading.Utils.Tar

data Args = Args
    { host       :: Maybe String <?> "host"
    , port       :: Maybe Int    <?> "port"
    , submission :: Int          <?> "submission id"
    , folder     :: FilePath     <?> "folder"
    } deriving (Show, Generic, ParseRecord)

main :: IO ()
main = do
    Args (Helpful mhost) (Helpful mport) (Helpful sid) (Helpful f) <- getRecord "Downloads a submission."
    let host' = fromMaybe "127.0.0.1" mhost
        port' = getPort mport
    sub <- getSubmissionIO host' port' $ SubmissionId sid
    putStrLn $ "downloaded submission " ++ show sid
    putStrLn $ "user: " ++ show (subUser sub)
    putStrLn $ "task: " ++ show (subTask sub)
    putStrLn $ "result: " ++ show (subResult sub)
    case subArchive sub of
        Nothing -> putStrLn "no archive"
        Just a  -> do
            extractArchive a f
            putStrLn $ "extracted archive to " ++ f
