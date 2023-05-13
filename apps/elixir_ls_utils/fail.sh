#!/bin/bash

cat test/fixtures/protocol_messages/output | elixir --erl "-noshell" -e ":io.setopts(:standard_io, encoding: :latin1, binary: true); IO.binread(:standard_io, :line) |> IO.inspect; IO.binread(:standard_io, :line) |> IO.inspect; IO.binread(:standard_io, 5832) |> IO.inspect"
