# Lazy Apps

## Introduction

This repository provides a simple customizable [Nix][] package,
`lazy-apps` that you can use to create a set of applications that
_appear_ to be installed on your system but are actually not until you
try to run them.

This is something of an intermediate step between packages installed
in your system/user profile and packages run through something like
[comma][] or [nix run][].

[Nix]: https://nixos.org/nix/
[comma]: https://github.com/nix-community/comma
[nix run]: https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-run

## Usage

Lazy Apps is currently made available as a Nix Flake. See the example
package in the Flake to get an idea about how it is used.
