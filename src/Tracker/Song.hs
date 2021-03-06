{-# LANGUAGE StrictData, TemplateHaskell, DerivingStrategies, DerivingVia #-}

-- | The 'Song' data type, and helper functions for working on it
module Tracker.Song where

import Data.Aeson.TH
import Data.Aeson
import GHC.Generics
import Data.Ix (Ix)
import Test.QuickCheck
import Test.QuickCheck.Gen

-- | A pitch, encoded MIDI-style (A4 is 69)
newtype Pitch = Pitch Int deriving (Eq, Ord, Num, Real, Enum, Ix, Integral, ToJSON, FromJSON, Arbitrary) via Int

instance Show Pitch where
  show p = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"] !! (fromIntegral p `mod` 12)

data Note = Note Pitch | Rest
          deriving (Show, Eq, Ord)

getOctave :: Pitch -> Int
getOctave p = fromIntegral p `div` 12

-- | A song is a sequence of notes, represented with a zipper.
data Song = Song
  { prevNotes :: [Note]
  , currentNote :: Note
  , nextNotes :: [Note]
  } deriving (Show, Eq, Ord)

forwardOneNote :: Song -> Maybe Song
forwardOneNote (Song prev curr (n:next)) = Just (Song (curr:prev) n next)
forwardOneNote (Song prev curr []) = Nothing -- End of the song!
  
backOneNote :: Song -> Maybe Song
backOneNote (Song (p:prev) curr next) = Just (Song prev p (curr:next))
backOneNote (Song [] curr next) = Nothing -- Start of the song!

deleteNote :: Song -> Maybe Song
deleteNote (Song prev _ (n:next)) = Just $ Song prev n next
deleteNote (Song (p:prev) _ [])   = Just $ Song prev p []
deleteNote (Song [] _ [])         = Nothing

deleteNote' :: Song -> Maybe Song
deleteNote' (Song (p:prev) _ next) = Just $ Song prev p next
deleteNote' (Song [] _ (n:next))   = Just $ Song [] n next
deleteNote' (Song [] _ [])         = Nothing

goToBeginning :: Song -> Song
goToBeginning (Song (p:prev) curr next) = goToBeginning (Song prev p (curr:next))
goToBeginning song = song

-- for JSON serialization and deserialization
$(deriveJSON defaultOptions ''Note)
$(deriveJSON defaultOptions ''Song)


exampleSong :: Song
exampleSong = Song [] curr next
  where curr:next = map Note [62,64,65,67,64,64,60,62]

emptySong :: Song
emptySong = Song [] Rest []

-- | Unit tests with QuickCheck

instance Arbitrary Note where
  arbitrary = maybe Rest Note <$> arbitrary
instance Arbitrary Song where
  arbitrary = Song <$> arbitrary <*> arbitrary <*> arbitrary

-- Moving forward followed by moving backwards does nothing
forwardAndBack song = maybe True (==song) $ forwardOneNote song >>= backOneNote
-- Moving backwards followed by moving forward does nothing
backAndForward song = maybe True (==song) $ backOneNote song >>= forwardOneNote
-- Serializing and deserializing are inverses
serde song = decode (encode song) == Just song
-- Moving forwards in the empty song is impossible
forwardsOfEmpty = forwardOneNote emptySong == Nothing
-- Moving backwards in the empty song is impossible
backOfEmpty = backOneNote emptySong == Nothing
-- Moving backwards at the beginning is impossible
backAtBeginning song = backOneNote (goToBeginning song) == Nothing