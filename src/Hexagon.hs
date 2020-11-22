{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}

module Hexagon
  ( hexagon
  , HexagonSettings
  , defHex
  , hexagon_postion
  , hexagon_color
  , hexagon_is_filled
  , renderTile
  , pixelToTile
  , tileToPixel
  , hexSize
  )
where

import           Control.Lens
import           Control.Monad.Reader (MonadReader (..))
import           Data.Foldable
import           Data.Int
import           Data.Text            (Text)
import qualified Data.Text            as Text
import qualified Data.Vector.Storable as S
import qualified Font
import           Foreign.C.Types      (CInt)
import           Grid
import           Layer
import           Reflex
import           Reflex.SDL2
import           SDL.Primitive
import           Text.Printf

data HexagonSettings = HexagonSettings
  { _hexagon_postion   :: Point V2 CInt
  , _hexagon_label     :: Maybe Text
  , _hexagon_color     :: Color
  , _hexagon_is_filled :: Bool
  }
makeLenses ''HexagonSettings

quotV2 :: V2 CInt -> V2 CInt -> V2 CInt
quotV2 (V2 x y) (V2 x2 y2) = V2 (x `quot` x2) $ y `quot` y2

hexSize :: Int
hexSize = 80

defHex :: HexagonSettings
defHex = HexagonSettings { _hexagon_postion = _Point # V2 150 150
                         , _hexagon_label   = Nothing
                         , _hexagon_color   = V4 128 128 128 255
                        , _hexagon_is_filled = False
                         }

-- | The corners of a hexagon labeled.
--
--                        top point
--   top left point                    top right point
--   bottom left point                 bottom right point
--                      bottom point
data HexCorner = TopRightPoint
              | BottomRightPoint
              | BottomPoint
              | BottomLeftPoint
              | TopLeftPoint
              | TopPoint
              deriving (Enum, Bounded)

cornerToDegree :: HexCorner -> Int
cornerToDegree = \case
  TopRightPoint    -> 330
  BottomRightPoint -> 30
  BottomPoint      -> 90
  BottomLeftPoint  -> 150
  TopLeftPoint     -> 210
  TopPoint         -> 270

-- https://www.redblobgames.com/grids/hexagons/#angles
pointyHexCorner :: Point V2 CInt -> Int -> HexCorner -> Point V2 CInt
pointyHexCorner (P (V2 x y)) hexSize' corner =
  (P $ V2 (x + (floor $ fromIntegral hexSize' * cos rad))
          (y + (floor $ fromIntegral hexSize' * sin rad))
  )
 where
  degree :: Double
  degree = fromIntegral $ cornerToDegree corner
  rad :: Double
  rad = pi / 180 * (degree)

-- | Calc the points to render, we are pointy top.
--  https://www.redblobgames.com/grids/hexagons/#basics
calcPoints :: HexagonSettings -> (S.Vector Int16, S.Vector Int16)
calcPoints settings =
  ( S.fromList $ fromIntegral . view _x <$> points
  , S.fromList $ fromIntegral . view _y <$> points
  )
 where
  points :: [Point V2 CInt]
  points =  pointyHexCorner (settings ^. hexagon_postion) hexSize <$> allCorners
  allCorners :: [HexCorner]
  allCorners = [minBound .. maxBound]


-- TODO:
-- 3. detect click. https://www.redblobgames.com/grids/hexagons/#pixel-to-hex
hexagon
  :: ReflexSDL2 t m
  => MonadReader Renderer m
  => DynamicWriter t [Layer m] m => HexagonSettings -> m ()
hexagon settings = do
  r    <- ask
  font <- Font.defaultFont
  evPB <- holdDyn () =<< getPostBuild
  commitLayer $ ffor evPB $ const $ do
    polgyonF r xPoints yPoints $ settings ^. hexagon_color
    for_ (settings ^. hexagon_label) $ \text -> do
      textSurface <- Font.solid font (settings ^. hexagon_color) text
      fontHexSize <- fmap fromIntegral . uncurry V2 <$> Font.size font text
      textTexture <- createTextureFromSurface r textSurface -- I think textures are cleaned automatically
      freeSurface textSurface
      copy r textTexture Nothing
        $ Just
        $ Rectangle
            (  settings
            ^. hexagon_postion
            -  (_Point # fontHexSize `quotV2` V2 2 (-5))
            )
        $ fontHexSize
  pure ()
  where
    (xPoints, yPoints) = calcPoints settings
    polgyonF = if settings ^. hexagon_is_filled then fillPolygon else polygon

-- https://www.redblobgames.com/grids/hexagons/#hex-to-pixel
renderTile :: Tile -> HexagonSettings
renderTile tile = hexagon_postion .~ (tileToPixel tile)
                $ hexagon_label ?~ (Text.pack $ printf "%i,%i" (tile ^. _q) $ (tile ^. _r))
                $ defHex

-- https://www.redblobgames.com/grids/hexagons/#hex-to-pixel
tileToPixel :: Tile -> Point V2 CInt
tileToPixel tile = (P $ V2 x y)
 where
  x :: CInt
  x =
    floor
      $ fromIntegral hexSize
      * ( (sqrt3 * (fromIntegral $ tile ^. _q))
        + (sqrt3 / 2.0 * (fromIntegral $ tile ^. _r))
        )
  y :: CInt
  y = floor $ fromIntegral hexSize * (3.0 / two * (fromIntegral $ tile ^. _r))

-- https://www.redblobgames.com/grids/hexagons/#pixel-to-hex
pixelToTile :: Point V2 CInt -> Tile
pixelToTile (P vec) = roundTile q r
 where
    -- TODO Implement hexSize properly, this math is crazy
  q :: Double
  q = ((sqrt3 / 3) * fromIntegral x - (1 / 3) * fromIntegral y)
    / fromIntegral hexSize
  r :: Double
  r = ((two / 3) * fromIntegral y) / fromIntegral hexSize
  y = vec ^. _y
  x = vec ^. _x

sqrt3 :: Double
sqrt3 = sqrt 3.0

two :: Double
two = 2.0
