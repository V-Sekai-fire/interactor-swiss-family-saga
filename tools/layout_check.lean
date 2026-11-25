-- SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
-- SPDX-License-Identifier: Apache-2.0 OR MIT
-- Verifies the layout rules of the game screen on the dump made by game/tests/layout.gd, for every state a player can reach:
--   1. a control lies inside the window;
--   2. a control lies inside the control that holds it;
--   3. a control is at least as large as the least it needs (its content fits);
--   4. a line of text that is not wrapped fits its width, and wrapped text shows all its lines;
--   5. two controls in one container do not overlap.
-- Usage: lean --run tools/layout_check.lean layout.json   (exit 1 when a rule is broken)
import Lean.Data.Json
open Lean

structure Node where
  path : String
  parent : String
  cls : String
  x : Float
  y : Float
  w : Float
  h : Float
  minW : Float
  minH : Float
  container : Bool
  text : String
  textWidth : Float
  autowrap : Bool
  lines : Float
  visibleLines : Float

def field (j : Json) (k : String) : Json := (j.getObjVal? k).toOption.getD Json.null
def numOf (j : Json) : Float := match j.getNum? with | .ok n => n.toFloat | .error _ => 0.0
def strOf (j : Json) : String := (j.getStr?).toOption.getD ""
def boolOf (j : Json) : Bool := (j.getBool?).toOption.getD false
def pair (j : Json) (i : Nat) : Float := match j.getArr? with | .ok a => numOf (a.getD i Json.null) | .error _ => 0.0

def nodeOf (j : Json) : Node :=
  let r := field j "rect"
  let m := field j "min"
  { path := strOf (field j "path"), parent := strOf (field j "parent"), cls := strOf (field j "cls"),
    x := pair r 0, y := pair r 1, w := pair r 2, h := pair r 3, minW := pair m 0, minH := pair m 1,
    container := boolOf (field j "container"), text := strOf (field j "text"), textWidth := numOf (field j "text_width"),
    autowrap := boolOf (field j "autowrap"), lines := numOf (field j "lines"), visibleLines := numOf (field j "visible_lines") }

def tol : Float := 1.5

def inside (n : Node) (x y w h : Float) : Bool :=
  n.x >= x - tol && n.y >= y - tol && n.x + n.w <= x + w + tol && n.y + n.h <= y + h + tol

def overlaps (a b : Node) : Bool :=
  let ox := (min (a.x + a.w) (b.x + b.w)) - (max a.x b.x)
  let oy := (min (a.y + a.h) (b.y + b.h)) - (max a.y b.y)
  ox > tol && oy > tol

def fmt (n : Node) : String := s!"{n.path} ({n.cls}) at {n.x.toUInt64},{n.y.toUInt64} size {n.w.toUInt64}x{n.h.toUInt64}"

def checkState (ww wh : Float) (name : String) (nodes : Array Node) : List String := Id.run do
  let mut bad : List String := []
  for n in nodes do
    if n.w <= 0 || n.h <= 0 then continue
    if !inside n 0 0 ww wh then
      bad := bad ++ [s!"{name}: outside the window: {fmt n}"]
    match nodes.find? (·.path == n.parent) with
    | some p =>
      if p.w > 0 && !inside n p.x p.y p.w p.h then
        bad := bad ++ [s!"{name}: outside its box {p.path}: {fmt n}"]
    | none => pure ()
    if n.w + tol < n.minW || n.h + tol < n.minH then
      bad := bad ++ [s!"{name}: smaller than its content needs ({n.minW.toUInt64}x{n.minH.toUInt64}): {fmt n}"]
    if !n.autowrap && n.text != "" && n.textWidth > n.w + tol then
      bad := bad ++ [s!"{name}: text wider than its control ({n.textWidth.toUInt64} > {n.w.toUInt64}): {fmt n}"]
    if n.autowrap && n.lines > n.visibleLines then
      bad := bad ++ [s!"{name}: text has lines that are not shown: {fmt n}"]
  -- siblings in one container must not overlap
  for a in nodes do
    if a.w <= 0 || a.h <= 0 then continue
    let parentIsContainer := (nodes.find? (·.path == a.parent)).map (·.container) |>.getD false
    if !parentIsContainer then continue
    for b in nodes do
      if a.path < b.path && a.parent == b.parent && b.w > 0 && b.h > 0 && overlaps a b then
        bad := bad ++ [s!"{name}: overlap in {a.parent}: {a.path} and {b.path}"]
  return bad

def main (args : List String) : IO UInt32 := do
  let some path := args.head? | IO.eprintln "usage: lean --run tools/layout_check.lean layout.json"; return 2
  let text ← IO.FS.readFile path
  let some j := (Json.parse text).toOption | IO.eprintln "not JSON"; return 2
  let win := field j "window"
  let ww := pair win 0
  let wh := pair win 1
  let states := (field j "states").getArr?.toOption.getD #[]
  let mut total := 0
  let mut broken := 0
  let mut shown := 0
  for s in states do
    let nodes := ((field s "nodes").getArr?.toOption.getD #[]).map nodeOf
    let bad := checkState ww wh (strOf (field s "name")) nodes
    total := total + 1
    if !bad.isEmpty then broken := broken + 1
    for b in bad do
      if shown < 2000 then IO.println b
      shown := shown + 1
  IO.println s!"layout: {total} states, {broken} with a broken rule, {shown} violations in all"
  return (if shown == 0 then 0 else 1)
