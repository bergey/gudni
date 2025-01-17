{-# LANGUAGE FlexibleContexts #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Graphics.Gudni.Raster.StrandLookupTable
-- Copyright   :  (c) Ian Bloom 2019
-- License     :  BSD-style (see the file libraries/base/LICENSE)
--
-- Maintainer  :  Ian Bloom
-- Stability   :  experimental
-- Portability :  portable
--
-- Functions for building a lookup table for reordering sequenced strands into
-- binary trees based on their length.

module Graphics.Gudni.Raster.ReorderTable
  ( ReorderTable
  , buildReorderTable
  , fromReorderTable
  )
where

import Graphics.Gudni.Util.Util
import Graphics.Gudni.Figure
import Graphics.Gudni.Util.Debug
import qualified Data.Vector.Storable as VS
import qualified Data.Vector as V
import Data.Vector ((!))
import Linear.V3

import Control.Lens


data ITree =
  IBranch
  { iTreeIndex :: Int
  , iTreeLeft  :: ITree
  , iTeeeRight :: ITree
  } |
  ILeaf

-- | Convert an ITree to a list.
subForest (IBranch _ left right) = [left, right]
subForest ILeaf = []

powerLess n x =
  --find a power of 2 <= n//2
  if x <= n `div` 2 then powerLess n (x * 2) else x

perfectTreePartition n =
    -- Find the point to partition n nodes for a perfect binary tree.
    let x = powerLess n 1
    in
    if (x `div` 2) - 1 <= n - x
    then x - 1             -- case 1
                           -- the left subtree of the root is perfect and the right subtree has less nodes or
    else n - (x `div` 2)   -- case 2 == n - (x//2 - 1) - 1
                           -- the left subtree of the root has more nodes and the right subtree is perfect.

buildITree xs =
   let l = length xs
       half = perfectTreePartition l
       left = take half xs
       rightCenter = drop half xs
       center = head rightCenter
       right = tail rightCenter
   in
       if l > 0
       then IBranch center (buildITree left) (buildITree right)
       else ILeaf

getIndex :: ITree -> [Int]
getIndex ILeaf = []
getIndex x = [iTreeIndex x]

breadth :: ITree -> [Int]
--breadth ILeaf = []
breadth nd = concatMap getIndex $ nd : breadth' [nd]
    where breadth' []  = []
          breadth' nds = let cs = foldr ((++).subForest) [] nds
                         in  cs ++ breadth' cs

makeTreeRow :: Int -> [Int]
makeTreeRow size =
  let internal = [0..(size `div` 2) - 1]
      halfTree = breadth $ buildITree internal
      doubleTree = map (*2) halfTree
      tree = concatMap (\x -> [x, x+1]) doubleTree
  in  tree

-- | Reorder the range so that the first three indices are to the
-- first point, first control point, and last point followed by the appropriate tree order for the rest which
-- is precomputed and provided by the ReorderTable
reorderForExtents :: Int -> Int -> [Int]
reorderForExtents maxSize size =
  if size < 3
  then []
  else [size - 1, 0, 1] ++
       if (size > 3)
       then map (+2) (makeTreeRow (size - 3))
       else []

type ReorderTable = V.Vector (V.Vector Int)

buildReorderTable :: Int -> ReorderTable
buildReorderTable maxSize = V.fromList $ map (V.fromList . reorderForExtents maxSize . (+1) . (*2)) [0..maxSize `div` 2]

tableRow :: ReorderTable -> Int -> V.Vector Int
tableRow table size = table ! (size `div` 2)

fromReorderTable :: ReorderTable -> Int -> Int -> Int
fromReorderTable table size i = (table ! (size `div` 2)) ! i
