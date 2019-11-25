{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE DeriveAnyClass    #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators     #-}

module Main
    ( main
    ) where

import Data.Maybe      (fromMaybe)
import Options.Generic
import Text.Printf     (printf)

import Grading.Client
import Grading.Types

data Args = Args
    { host   :: Maybe String <?> "host"
    , port   :: Maybe Int    <?> "port"
    , user   :: String       <?> "username"
    , task   :: Int          <?> "task id"
    , folder :: FilePath     <?> "submission folder"
    } deriving (Show, Generic, ParseRecord)

main :: IO ()
main = do
    Args (Helpful mhost) (Helpful mport) (Helpful u) (Helpful task') (Helpful folder')
        <- getRecord "Uploads a submission to the grading server."
    let host' = fromMaybe "127.0.0.1" mhost
        port' = getPort mport
    printf "uploading submission folder '%s' for task %d to %s:%d for user '%s'"
        folder' task' host' port' u
    uploadFolder host' port' (UserName u) task' folder'
