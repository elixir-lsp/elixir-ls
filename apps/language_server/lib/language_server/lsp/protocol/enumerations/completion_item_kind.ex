# codegen: do not edit
defmodule GenLSP.Enumerations.CompletionItemKind do
  @moduledoc """
  The kind of a completion entry.
  """

  @type t ::
          1
          | 2
          | 3
          | 4
          | 5
          | 6
          | 7
          | 8
          | 9
          | 10
          | 11
          | 12
          | 13
          | 14
          | 15
          | 16
          | 17
          | 18
          | 19
          | 20
          | 21
          | 22
          | 23
          | 24
          | 25

  import Schematic, warn: false

  @spec text() :: 1
  def text, do: 1

  @spec method() :: 2
  def method, do: 2

  @spec function() :: 3
  def function, do: 3

  @spec constructor() :: 4
  def constructor, do: 4

  @spec field() :: 5
  def field, do: 5

  @spec variable() :: 6
  def variable, do: 6

  @spec class() :: 7
  def class, do: 7

  @spec interface() :: 8
  def interface, do: 8

  @spec module() :: 9
  def module, do: 9

  @spec property() :: 10
  def property, do: 10

  @spec unit() :: 11
  def unit, do: 11

  @spec value() :: 12
  def value, do: 12

  @spec enum() :: 13
  def enum, do: 13

  @spec keyword() :: 14
  def keyword, do: 14

  @spec snippet() :: 15
  def snippet, do: 15

  @spec color() :: 16
  def color, do: 16

  @spec file() :: 17
  def file, do: 17

  @spec reference() :: 18
  def reference, do: 18

  @spec folder() :: 19
  def folder, do: 19

  @spec enum_member() :: 20
  def enum_member, do: 20

  @spec constant() :: 21
  def constant, do: 21

  @spec struct() :: 22
  def struct, do: 22

  @spec event() :: 23
  def event, do: 23

  @spec operator() :: 24
  def operator, do: 24

  @spec type_parameter() :: 25
  def type_parameter, do: 25

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25
    ])
  end
end
