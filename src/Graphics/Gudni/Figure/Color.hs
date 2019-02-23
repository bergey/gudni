{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE TypeSynonymInstances       #-}

module Graphics.Gudni.Figure.Color
  ( Color(..)
  , rgbaColor
  , hslColor

  , pureRed, pureGreen, pureBlue
  , red, orange, yellow, green, blue, purple
  , black, gray, white

  , saturate
  , lighten
  , light
  , dark
  , veryDark
  , transparent
  , clear
  , mixColor

  , redish, orangeish, yellowish, greenish, blueish, purpleish
  )
where

import Graphics.Gudni.Figure.Space
import Graphics.Gudni.Figure.Point

import Graphics.Gudni.Util.Debug
import Graphics.Gudni.Util.Util
import Graphics.Gudni.Util.StorableM

import Control.DeepSeq
import Control.Monad.Random

import Numeric
import Numeric.Half

import Data.Word
import Data.Bits
import Data.List
import Data.Map.Strict ((!))
import qualified Data.Map.Strict as M

import Foreign.Storable
import Foreign.C.Types
import qualified Foreign as F

import System.Random
import qualified Data.Colour as C
import qualified Data.Colour.RGBSpace.HSL as C
import qualified Data.Colour.RGBSpace as C
import qualified Data.Colour.SRGB as C
import qualified Data.Colour.Names as N

data Color = Color
    { unColor :: C.Colour Float
    , unAlpha :: Float
    }

instance Show Color where
  show (Color s a) = show s ++ " " ++ show a

pureRed   = rgbaColor 1 0 0 1
pureGreen = rgbaColor 0 1 0 1
pureBlue  = rgbaColor 0 0 1 1

red    = Color N.red    1.0
orange = Color N.orange 1.0
yellow = Color N.yellow 1.0
green  = Color N.green  1.0
blue   = Color N.blue   1.0
purple = Color N.purple 1.0
white  = Color N.white  1.0
gray   = Color N.gray   1.0
black  = Color C.black  1.0

hslColor :: Float -> Float -> Float -> Color
hslColor hue saturation lightness = Color (C.uncurryRGB C.sRGB $ C.hsl hue saturation lightness) 1.0

rgbaColor :: Float -> Float -> Float -> Float -> Color
rgbaColor r g b a = Color (C.sRGB r g b) a

saturate :: Float -> Color -> Color
saturate sat (Color colour a) =
    let (h, s, l) = C.hslView . C.toSRGB $ colour
        c = C.uncurryRGB C.sRGB $ C.hsl h (clamp 0 1.0 $ sat * s) l
    in  Color c a

lighten :: Float -> Color ->  Color
lighten light (Color colour a) =
  let (h, s, l) = C.hslView . C.toSRGB $ colour
      c = C.uncurryRGB C.sRGB $ C.hsl h s (clamp 0 1.0 $ light * l)
  in  Color c a

light :: Color -> Color
light = saturate 0.8  . lighten 1.25

dark :: Color -> Color
dark  = saturate 1.25 . lighten 0.75

veryDark :: Color -> Color
veryDark  = saturate 1.25 . lighten 0.5

clear :: Color -> Color
clear (Color colour a) = Color colour 0

mixColor :: Color -> Color -> Color
mixColor (Color cA aA) (Color cB aB) = Color (C.blend 0.5 cA cB) aA

influenceHue :: Float -> Color -> Color -> Color
influenceHue amount (Color blender bA) (Color color cA) =
  let blended = C.blend amount blender color
      (h,s,_) = C.hslView . C.toSRGB $ blended
      (_,_,l) = C.hslView . C.toSRGB $ color
  in  transparent cA $ hslColor h s l

ishAmount = 0.05

redish    :: Color -> Color
orangeish :: Color -> Color
yellowish :: Color -> Color
greenish  :: Color -> Color
blueish   :: Color -> Color
purpleish :: Color -> Color
redish    = influenceHue ishAmount red
orangeish = influenceHue ishAmount orange
yellowish = influenceHue ishAmount yellow
greenish  = influenceHue ishAmount green
blueish   = influenceHue ishAmount blue
purpleish = influenceHue ishAmount purple

transparent :: Float -> Color -> Color
transparent a (Color colour _) = Color colour a

instance StorableM Color where
  sizeOfM _ =
    do sizeOfM (undefined :: CFloat)
       sizeOfM (undefined :: CFloat)
       sizeOfM (undefined :: CFloat)
       sizeOfM (undefined :: CFloat)
  alignmentM _ =
    do alignmentM (undefined :: CFloat)
       alignmentM (undefined :: CFloat)
       alignmentM (undefined :: CFloat)
       alignmentM (undefined :: CFloat)
  peekM = do (red   :: Float) <- realToFrac <$> (peekM :: Offset CFloat)
             (green :: Float) <- realToFrac <$> (peekM :: Offset CFloat)
             (blue  :: Float) <- realToFrac <$> (peekM :: Offset CFloat)
             (alpha :: Float) <- realToFrac <$> (peekM :: Offset CFloat)
             return (Color (C.sRGB red green blue) alpha)
  pokeM (Color colour a) =
      do let rgb = C.toSRGB colour
         pokeM (realToFrac . C.channelRed   $ rgb :: CFloat)
         pokeM (realToFrac . C.channelGreen $ rgb :: CFloat)
         pokeM (realToFrac . C.channelBlue  $ rgb :: CFloat)
         pokeM (realToFrac                    a   :: CFloat)

instance Storable Color where
  sizeOf = sizeOfV
  alignment = alignmentV
  peek = peekV
  poke = pokeV

instance NFData Color where
  rnf color = ()