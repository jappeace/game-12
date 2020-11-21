module Test.HexagonSpec
  ( spec
  )
where

import           Foreign.C.Types (CInt)
import           Game13          ()
import           Grid
import           Hexagon
import           Reflex.SDL2
import           Test.Hspec
import           Test.Orphanage ()
import           Test.QuickCheck
import           Text.Printf


spec :: Spec
spec =
  describe "Tile to point to tile" $ do
    it "Tile should be isomorphic to Point V2 Cint" $ property isoTile
    it "Tile should be isomorphic to Point V2 Cint" $ property isoPoint

isoTile :: Tile -> Property
isoTile tile = counterexample (printf "actual result: %s" $ show other) $ other == tile
  where
    other = detectTile $ detectPoint tile

isoPoint :: Point V2 CInt -> Property
isoPoint point' = counterexample (printf "actual result: %s" $ show other) $ other == point'
  where
    other = detectPoint $ detectTile point'