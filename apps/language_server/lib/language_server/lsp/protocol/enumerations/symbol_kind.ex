# codegen: do not edit
defmodule GenLSP.Enumerations.SymbolKind do
  @moduledoc """
  A symbol kind.
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
          | 26

  import Schematic, warn: false

  @spec file() :: 1
  def file, do: 1

  @spec module() :: 2
  def module, do: 2

  @spec namespace() :: 3
  def namespace, do: 3

  @spec package() :: 4
  def package, do: 4

  @spec class() :: 5
  def class, do: 5

  @spec method() :: 6
  def method, do: 6

  @spec property() :: 7
  def property, do: 7

  @spec field() :: 8
  def field, do: 8

  @spec constructor() :: 9
  def constructor, do: 9

  @spec enum() :: 10
  def enum, do: 10

  @spec interface() :: 11
  def interface, do: 11

  @spec function() :: 12
  def function, do: 12

  @spec variable() :: 13
  def variable, do: 13

  @spec constant() :: 14
  def constant, do: 14

  @spec string() :: 15
  def string, do: 15

  @spec number() :: 16
  def number, do: 16

  @spec boolean() :: 17
  def boolean, do: 17

  @spec array() :: 18
  def array, do: 18

  @spec object() :: 19
  def object, do: 19

  @spec key() :: 20
  def key, do: 20

  @spec null() :: 21
  def null, do: 21

  @spec enum_member() :: 22
  def enum_member, do: 22

  @spec struct() :: 23
  def struct, do: 23

  @spec event() :: 24
  def event, do: 24

  @spec operator() :: 25
  def operator, do: 25

  @spec type_parameter() :: 26
  def type_parameter, do: 26

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
      25,
      26
    ])
  end
end
