{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecursiveDo #-}

module Guest(guest) where

import Render
import           Control.Monad.Reader           ( MonadReader(..) )
import           Reflex
import           Reflex.SDL2
import           Layer
import           Grid
import           Control.Lens
import           Data.Generics.Product
import           Data.Generics.Sum
import           Data.Int
import State

leftClick :: Prism' MouseButton ()
leftClick = _Ctor @"ButtonLeft"

rightClick :: Prism' MouseButton ()
rightClick = _Ctor @"ButtonRight"

mouseButtons :: Lens' MouseButtonEventData MouseButton
mouseButtons = field @"mouseButtonEventButton"

mousePositions :: Lens' MouseButtonEventData (Point V2 Int32)
mousePositions = field @"mouseButtonEventPos"

mouseMotion :: Lens' MouseButtonEventData InputMotion
mouseMotion = field @"mouseButtonEventMotion"

_Pressed :: Prism' InputMotion ()
_Pressed = _Ctor @ "Pressed"

guest
  :: forall t m
   . ReflexSDL2 t m
  => DynamicWriter t [Layer m] m => MonadReader Renderer m => m ()
guest = do
  -- Print some stuff after the network is built.
  evPB           <- getPostBuild
  performEvent_ $ ffor evPB $ \() -> liftIO $ putStrLn "starting up..."
  gameState <- mkGameState
  renderState gameState

mkGameState :: forall t m . ReflexSDL2 t m => m (Dynamic t GameState)
mkGameState = do
  mouseButtonEvt <- getMouseButtonEvent
  let leftClickEvts :: Event t MouseButtonEventData
      leftClickEvts = ffilter (has (mouseButtons . leftClick)) mouseButtonEvt
      rightClickEvts :: Event t MouseButtonEventData
      rightClickEvts = ffilter (\x -> has (mouseButtons . rightClick) x
                               && has (mouseMotion . _Pressed) x
                               ) mouseButtonEvt
      leftClickAxial = calcMouseClickAxial <$> leftClickEvts
      rightClickAxialEvt = calcMouseClickAxial <$> rightClickEvts
      events = leftmost [ LeftClick <$> leftClickAxial
                        , RightClick <$> rightClickAxialEvt
                        ]
  performEvent_ $ ffor events $ liftIO . print
  state <- accumDyn updateState initialState events
  performEvent_ $ ffor (describeState <$> updated state) $ liftIO . print
  pure state

calcMouseClickAxial :: MouseButtonEventData -> Axial
calcMouseClickAxial = pixelToAxial . fmap fromIntegral . view mousePositions
